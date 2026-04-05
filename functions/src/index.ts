import {setGlobalOptions} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {getStorage} from "firebase-admin/storage";
import {initializeApp} from "firebase-admin/app";

initializeApp();
setGlobalOptions({maxInstances: 10});

const db = getFirestore();
const messaging = getMessaging();

export const onEntryCreated = onDocumentCreated(
  "groups/{groupId}/rituals/{ritualId}/entries/{entryId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const entryData = snap.data();
    const {groupId} = event.params;
    const posterId = entryData.userId;

    // Get the group to find all members
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) return;

    const group = groupDoc.data();
    if (!group) return;

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
        ritualId: event.params.ritualId,
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

// Runs every hour — sends reminder notifications for rituals whose reminderTime
// matches the current UTC hour on a scheduled day.
export const sendDailyReminders = onSchedule("every 60 minutes", async () => {
  const now = new Date();
  const hour = now.getUTCHours().toString().padStart(2, "0");
  const minute = now.getUTCMinutes().toString().padStart(2, "0");
  const currentTime = `${hour}:${minute}`;

  // JS getDay(): 0=Sun..6=Sat → Dart weekday: 1=Mon..7=Sun
  const jsDay = now.getUTCDay();
  const dartWeekday = jsDay === 0 ? 7 : jsDay;

  const groupsSnapshot = await db.collection("groups").get();

  for (const groupDoc of groupsSnapshot.docs) {
    const groupId = groupDoc.id;
    const memberIds: string[] = groupDoc.data().memberIds ?? [];

    const ritualsSnapshot = await db
      .collection("groups")
      .doc(groupId)
      .collection("rituals")
      .where("reminderTime", "==", currentTime)
      .get();

    for (const ritualDoc of ritualsSnapshot.docs) {
      const ritual = ritualDoc.data();
      const scheduleDays: number[] = ritual.scheduleDays ?? [];
      if (!scheduleDays.includes(dartWeekday)) continue;

      const tokens: string[] = [];
      for (const uid of memberIds) {
        const userDoc = await db.collection("users").doc(uid).get();
        const token = userDoc.data()?.fcmToken;
        if (token) tokens.push(token);
      }
      if (tokens.length === 0) continue;

      await messaging.sendEachForMulticast({
        tokens,
        notification: {
          title: `${ritual.emoji as string} Time for ${ritual.title as string}!`,
          body: "Don't forget your ritual today",
        },
        data: {groupId, ritualId: ritualDoc.id, type: "reminder"},
      });

      console.log(
        `Reminder sent for ${ritual.title as string} in group ${groupId}`
      );
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
