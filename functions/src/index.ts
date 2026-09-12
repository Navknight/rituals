import {setGlobalOptions} from "firebase-functions";
import {onMessagePublished} from "firebase-functions/v2/pubsub";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {getStorage} from "firebase-admin/storage";
import {initializeApp} from "firebase-admin/app";
import {CloudBillingClient} from "@google-cloud/billing";

initializeApp();
setGlobalOptions({maxInstances: 10});

const db = getFirestore();
const messaging = getMessaging();

export const onEntryCreated = onDocumentCreated(
  "groups/{groupId}/entries/{entryId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const entryData = snap.data();
    const {groupId} = event.params;
    const posterId = entryData.userId;
    const ritualId = entryData.ritualId ?? "";

    // Only photos are worth interrupting anyone for.
    if (!entryData.photoUrl) return;

    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) return;

    const group = groupDoc.data();
    if (!group) return;

    // Nobody to notify in a space of one.
    if (group.isPersonal === true) return;

    // Get FCM tokens for all members except the poster
    const memberIds: string[] = group.memberIds.filter(
      (id: string) => id !== posterId
    );

    const tokens: string[] = [];
    for (const uid of memberIds) {
      const userDoc = await db.collection("users").doc(uid).get();
      const userData = userDoc.data();
      if (userData?.fcmToken) {
        tokens.push(userData.fcmToken);
      }
    }

    if (tokens.length === 0) return;

    // Get poster's display name
    const posterDoc = await db.collection("users").doc(posterId).get();
    const posterName = posterDoc.data()?.displayName ?? "Someone";

    // Send FCM notification to all other members
    const body = entryData.caption ?
      `${posterName}: ${entryData.caption}` :
      `${posterName} shared a photo`;

    const message = {
      tokens,
      notification: {
        title: "New photo!",
        body,
      },
      data: {
        groupId,
        ritualId,
        entryId: event.params.entryId,
        photoUrl: entryData.photoUrl ?? "",
      },
    };

    const response = await messaging.sendEachForMulticast(message);
    console.log(
      `Sent ${response.successCount}/${tokens.length} notifications`
    );

    // Clean up invalid tokens
    response.responses.forEach((resp, idx) => {
      if (
        !resp.success &&
        resp.error?.code ===
          "messaging/invalid-registration-token"
      ) {
        // Token is invalid, could remove from user doc
        console.log(`Invalid token for index ${idx}`);
      }
    });
  }
);

export const onNudgeCreated = onDocumentCreated(
  "groups/{groupId}/rituals/{ritualId}/nudges/{nudgeId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const nudgeData = snap.data();
    const {groupId, ritualId} = event.params;
    const {fromUid, toUid, ritualTitle} = nudgeData;

    // Get FCM token for the nudged user
    const toUserDoc = await db.collection("users").doc(toUid).get();
    const fcmToken = toUserDoc.data()?.fcmToken;
    if (!fcmToken) {
      await snap.ref.delete();
      return;
    }

    // Get sender name
    const fromUserDoc = await db.collection("users").doc(fromUid).get();
    const fromName = fromUserDoc.data()?.displayName ?? "Someone";

    await messaging.send({
      token: fcmToken,
      notification: {
        title: "Time to post! 👀",
        body: `${fromName} is waiting for your ${ritualTitle} photo`,
      },
      data: {groupId, ritualId},
    });

    // Delete the nudge document after sending
    await snap.ref.delete();
  }
);

// Mirrors the reminder lines in lib/features/commentary/lines.dart. Kept here
// so a push notification sounds like the rest of the app.
const REMINDER_LINES: Record<string, string[]> = {
  kind: [
    "Time for {ritual}.",
    "{ritual} is waiting whenever you are.",
    "A small window for {ritual}.",
  ],
  dry: [
    "{ritual}. Now would be the time.",
    "{ritual} is due. No pressure, obviously.",
    "Reminder: {ritual}. You did ask for this.",
  ],
  brutal: [
    "{ritual}. Now. Before you talk yourself out of it.",
    "{ritual} is due and your excuses are getting worse.",
    "Get up. {ritual}. It takes less time than the guilt.",
  ],
  brutalProfane: [
    "{ritual}. Now. Before you talk yourself out of it.",
    "Get off your arse. {ritual} is due.",
    "{ritual}. Damn it, you set this reminder yourself.",
  ],
};

function reminderBody(
  tone: string | undefined,
  allowProfanity: boolean,
  ritual: string
): string {
  if (tone === "off") return "";
  let key = tone ?? "kind";
  if (key === "brutal" && allowProfanity) key = "brutalProfane";
  const pool = REMINDER_LINES[key] ?? REMINDER_LINES.kind;
  const line = pool[Math.floor(Math.random() * pool.length)];
  return line.replace("{ritual}", ritual);
}

function dayKey(date: Date): string {
  const y = date.getFullYear();
  const m = (date.getMonth() + 1).toString().padStart(2, "0");
  const d = date.getDate().toString().padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function isDueOn(ritual: FirebaseFirestore.DocumentData, local: Date): boolean {
  const weekday = local.getDay() === 0 ? 7 : local.getDay();
  const scheduleType = ritual.scheduleType ?? "weekdays";

  if (scheduleType === "timesPerWeek") return true;

  if (scheduleType === "everyNDays") {
    const interval: number = ritual.intervalDays ?? 1;
    if (interval < 1) return true;
    const createdAt = ritual.createdAt?.toDate?.();
    if (!createdAt) return true;
    const start = Date.UTC(
      createdAt.getFullYear(), createdAt.getMonth(), createdAt.getDate()
    );
    const today = Date.UTC(
      local.getFullYear(), local.getMonth(), local.getDate()
    );
    const elapsed = Math.round((today - start) / 86400000);
    return elapsed >= 0 && elapsed % interval === 0;
  }

  const scheduleDays: number[] = ritual.scheduleDays ?? [];
  return scheduleDays.includes(weekday);
}

// Runs every 15 minutes. A ritual's reminderTime is local, so it is shifted by
// the offset stored with it to decide whether it is due right now.
export const sendDailyReminders = onSchedule("every 15 minutes", async () => {
  const now = new Date();

  const groupsSnapshot = await db.collection("groups").get();

  for (const groupDoc of groupsSnapshot.docs) {
    const groupId = groupDoc.id;
    const memberIds: string[] = groupDoc.data().memberIds ?? [];
    if (memberIds.length === 0) continue;

    const ritualsSnapshot = await db
      .collection("groups")
      .doc(groupId)
      .collection("rituals")
      .where("reminderTime", "!=", null)
      .get();

    for (const ritualDoc of ritualsSnapshot.docs) {
      const ritual = ritualDoc.data();
      if (ritual.archived === true) continue;

      const reminderTime: string | undefined = ritual.reminderTime;
      if (!reminderTime) continue;

      const offsetMinutes: number = ritual.reminderOffsetMinutes ?? 0;
      const local = new Date(now.getTime() + offsetMinutes * 60000);

      const [hourPart, minutePart] = reminderTime.split(":");
      const targetMinutes =
        parseInt(hourPart, 10) * 60 + parseInt(minutePart, 10);
      const localMinutes = local.getUTCHours() * 60 + local.getUTCMinutes();

      // The schedule runs every 15 minutes, so fire once inside that window.
      const delta = localMinutes - targetMinutes;
      if (delta < 0 || delta >= 15) continue;

      const localDay = new Date(local.getTime());
      if (!isDueOn(ritual, new Date(
        localDay.getUTCFullYear(),
        localDay.getUTCMonth(),
        localDay.getUTCDate()
      ))) continue;

      const today = dayKey(new Date(
        localDay.getUTCFullYear(),
        localDay.getUTCMonth(),
        localDay.getUTCDate()
      ));

      // Skip anyone who already logged it today.
      const loggedSnapshot = await db
        .collection("groups")
        .doc(groupId)
        .collection("entries")
        .where("ritualId", "==", ritualDoc.id)
        .where("day", "==", today)
        .get();

      const alreadyLogged = new Set(
        loggedSnapshot.docs.map((doc) => doc.data().userId as string)
      );

      // Each member hears the reminder in the tone they chose.
      let sent = 0;
      for (const uid of memberIds) {
        if (alreadyLogged.has(uid)) continue;
        const userData = (await db.collection("users").doc(uid).get()).data();
        const token = userData?.fcmToken;
        if (!token) continue;

        const body = reminderBody(
          userData?.commentaryTone,
          userData?.allowProfanity === true,
          ritual.title as string
        );
        if (!body) continue;

        await messaging.send({
          token,
          notification: {
            title: `${ritual.emoji as string} ${ritual.title as string}`,
            body,
          },
          data: {groupId, ritualId: ritualDoc.id, type: "reminder"},
        });
        sent++;
      }

      if (sent > 0) {
        console.log(
          `Reminder sent to ${sent} for ${ritual.title as string} in ${groupId}`
        );
      }
    }
  }
});

export const cleanupRelayPhotos = onSchedule("every 24 hours", async () => {
  const bucket = getStorage().bucket();
  const [files] = await bucket.getFiles({prefix: "relay/"});

  // Sort oldest first (FIFO)
  const sorted = [...files].sort((a, b) => {
    const aTime = new Date(a.metadata.timeCreated as string).getTime();
    const bTime = new Date(b.metadata.timeCreated as string).getTime();
    return aTime - bTime;
  });

  // Sum total size
  const totalBytes = sorted.reduce((sum, file) => {
    return sum + parseInt((file.metadata.size as string) ?? "0", 10);
  }, 0);

  const limitBytes = 900 * 1024 * 1024; // 900 MB — 100 MB headroom on 1 GB free tier

  if (totalBytes <= limitBytes) {
    console.log(`Storage OK: ${(totalBytes / 1024 / 1024).toFixed(1)} MB used`);
    return;
  }

  // Delete oldest files until under limit
  let remaining = totalBytes;
  let freed = 0;
  const toDelete = [];

  for (const file of sorted) {
    if (remaining <= limitBytes) break;
    const fileSize = parseInt((file.metadata.size as string) ?? "0", 10);
    toDelete.push(file);
    remaining -= fileSize;
    freed += fileSize;
  }

  await Promise.all(toDelete.map((file) => file.delete()));
  console.log(
    `FIFO cleanup: deleted ${toDelete.length} files, freed ${(freed / 1024 / 1024).toFixed(1)} MB. ` +
    `Now ~${(remaining / 1024 / 1024).toFixed(1)} MB used`
  );
});

// Hard spending cap. A Cloud Billing budget publishes to the billing-alerts
// topic; when actual spend passes the budget this detaches the billing account
// from the project, which stops every billable service. A budget alert only
// reports that money was spent. This stops it being spent.
export const capSpending = onMessagePublished(
  {topic: "billing-alerts", retry: false},
  async (event) => {
    const data = event.data.message.json as {
      costAmount?: number;
      budgetAmount?: number;
    };

    const cost = data.costAmount ?? 0;
    const budget = data.budgetAmount ?? 0;

    if (cost <= budget) {
      console.log(`Spend ${cost} is within budget ${budget}.`);
      return;
    }

    const projectId = process.env.GCLOUD_PROJECT;
    if (!projectId) {
      console.error("GCLOUD_PROJECT unset, cannot disable billing.");
      return;
    }

    const name = `projects/${projectId}`;
    const billing = new CloudBillingClient();

    const [info] = await billing.getProjectBillingInfo({name});
    if (!info.billingAccountName) {
      console.log("Billing is already disabled.");
      return;
    }

    await billing.updateProjectBillingInfo({
      name,
      projectBillingInfo: {billingAccountName: ""},
    });

    console.error(
      `BILLING DISABLED for ${projectId}: ${cost} exceeded budget ${budget}.`
    );
  }
);
