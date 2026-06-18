# Rituals

Group habit tracker with photo proof. Build streaks with friends.

## What it does

Create shared rituals, daily or weekly habits, and hold each other accountable by posting photos. See everyone's streak, nudge members who haven't posted, and browse the photo history by day.

**Core flow:**
1. Sign in with Google
2. Create or join a group (via invite code or QR scan)
3. Add rituals with an emoji, schedule (weekdays), and optional reminder time
4. Tap a ritual → take a photo → ritual marked complete for the day
5. See the group streak, nudge stragglers, browse past photos

## Features

- **Photo proof**: camera capture with caption, saved locally and to Firebase Storage
- **Streaks**: current streak, longest this month, longest overall; calendar heatmap
- **Nudges**: tap to send a push notification to members who haven't posted today
- **Push notifications**: new photo alerts, nudge pings, scheduled reminders
- **Home screen widget**: shows the latest group photo (Android/iOS)
- **QR invite**: scan to join a group without typing a code
- **Web support**: runs as a PWA alongside the mobile apps

## Tech stack

| Layer | Technology |
|---|---|
| UI | Flutter (Dart) |
| State | Riverpod |
| Navigation | GoRouter |
| Auth | Firebase Auth + Google Sign-In |
| Database | Cloud Firestore |
| Storage | Firebase Storage |
| Notifications | Firebase Cloud Messaging |
| Backend | Cloud Functions (TypeScript) |

## Photo storage and peer restore

Photos in Rituals are **temporary proof**, not a permanent archive. The app's purpose is building habits, photos just confirm you did the thing. To this end and my own financial sanity I created a peer to peer storage solution with firebase acting as the temporary relay.

Photos live in Firebase Storage under `relay/` and are cleaned up daily once the bucket nears its limit (oldest first). There's no guarantee a photo URL stays valid forever.

**What happens when a photo link breaks:**

When a device can't load a photo, it drops a restore request into Firestore. The next time any group member opens the app, their device checks for pending requests and, if it has the photo, re-uploads it to Storage and updates the link. Everyone watching that entry sees the new URL in real time via a Firestore stream.

The original poster is the most reliable fulfiller since the photo is saved locally on their device at capture time. Other members can help too if they've previously viewed and cached it.

Firebase coordinates the whole exchange (Firestore for the request, Storage for the re-upload), devices never talk to each other directly.

## Cloud Functions

- `onEntryCreated` — notifies group members when someone posts a photo
- `onNudgeCreated` — delivers nudge notifications and cleans up the nudge doc
- `sendDailyReminders` — runs every hour; sends reminders for rituals whose `reminderTime` matches the current UTC time
- `cleanupRelayPhotos` — daily FIFO cleanup of `relay/` storage, keeps usage under 900 MB

## Project structure

```
lib/
  app/          # router, theme, main scaffold
  features/     # auth, camera, groups, home, rituals, streaks
  models/       # Ritual, RitualEntry, Group, UserProfile
  services/     # auth, group, notification, photo, ritual, streak, user, widget
  shared/       # reusable widgets (heatmap, avatar, download helpers)
functions/src/  # Cloud Functions (TypeScript)
```

## Setup

1. Create a Firebase project and add Android/iOS/Web apps
2. Run `flutterfire configure` to generate `lib/firebase_options.dart`
3. Enable Google Sign-In in Firebase Auth
4. Deploy Firestore rules: `firebase deploy --only firestore:rules`
5. Deploy functions: `cd functions && npm install && firebase deploy --only functions`
6. Run: `flutter run`
