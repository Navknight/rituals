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

export const cleanupRelayPhotos = onSchedule("every 24 hours", async () => {
  const bucket = getStorage().bucket();
  const [files] = await bucket.getFiles({prefix: "relay/"});

  const cutoffMs = Date.now() - 30 * 24 * 60 * 60 * 1000;
  const toDelete = files.filter((file) => {
    const created = file.metadata.timeCreated as string | undefined;
    return created && new Date(created).getTime() < cutoffMs;
  });

  await Promise.all(toDelete.map((file) => file.delete()));
  console.log(`Deleted ${toDelete.length} relay photos older than 7 days`);
});
