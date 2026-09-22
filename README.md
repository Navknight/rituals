# Rituals

A habit tracker you can use alone, or with people who will notice when you stop.

## What it does

Sign in, and a private space is waiting for you. Add a ritual, then prove you
did it with a photo. Streaks, consistency and calendars build up from there. If
you want other people involved, create a shared space and send them a code.
Nothing about the app requires it.

**The short version:**
1. Start tracking as a guest, or sign in with Google
2. Add a ritual: a name, an emoji, how often, and what counts as doing it
3. Tap it, take the photo. The day counts once the photo is in
4. Swipe to skip a day without losing the streak
5. Watch the score, heatmap and charts fill in
6. Optionally share a space with friends and hold each other to it

## Photo proof

**A day does not count until a photo is attached.** That is the core rule and
the reason the app exists: a tick box is easy to lie to, a photo is not. Hitting
a target without proof leaves the day sitting at partial, and partial does not
extend a streak.

Photo proof is on by default for every new ritual. Tapping a ritual opens the
camera rather than ticking a box. You can turn it off per ritual, on the "Photo
proof" switch in the editor, for the handful of habits a photo cannot capture.

### Gallery photos

A shot taken in the moment is the stronger proof, so by default a ritual that
asks for proof only accepts the camera. Some habits cannot be photographed as
they happen, though — a swim, a run in the rain, anything where the phone stays
in a locker — so each ritual has an **"Allow gallery photos"** switch under
"Photo proof". Turn it on and the camera screen grows a gallery button; leave it
off and the only way in is the shutter.

Rituals that do not require proof were never guarding anything, so their
optional photos can always come from the gallery. If the camera cannot be
opened at all — no camera, permission denied, a locked-down browser — the screen
says so and offers the gallery instead, where the ritual allows it.

Opening the system picker pushes the app to the background, where Android is
free to kill it to reclaim memory. Samsung's One UI does this routinely, and
when it happens the picked photo never comes back through the call that asked
for it — which looks, from the outside, exactly like gallery picking not
working on Samsung phones at all. The app now notes down which ritual a pick
was for before opening the picker, and collects the orphaned photo on next
launch via `retrieveLostData`, carrying it on to the preview as if nothing had
happened.

## Tracking

**Three kinds of ritual**

| Type | What counts as done | Example |
|---|---|---|
| Check | One tap | Make the bed |
| Count | A daily target and unit | 8 glasses of water |
| Timer | A daily target in minutes | 20 minutes reading |

Count and timer rituals accumulate through the day and show partial progress in
the ring.

**Three kinds of schedule**

- Fixed weekdays, for example Monday, Wednesday, Friday
- A weekly quota, for example 3 times per week on any days you like
- Every N days, counting from the day you created it

**Skips, not misses.** Swipe a ritual and skip it. A skipped day is a deliberate
rest day: it holds your streak without extending it, and it stays out of your
completion rate entirely. Rest days from the schedule work the same way, so a
Monday-only ritual does not lose its streak on Tuesday.

## Stats

**Habit score.** Streaks are brittle: one bad day erases months. Alongside the
streak, every ritual has a score from 0 to 100%, the exponential moving average
Loop Habit Tracker uses:

```
multiplier = 0.5 ^ (frequencyInDays / 13)
score      = previousScore * multiplier + todaysProgress * (1 - multiplier)
```

Keep a daily ritual perfectly and the score reaches about 80% after a month and
96% after two. Miss a day and it dips rather than resets. `frequencyInDays`
comes from the schedule, so a three-times-a-week ritual is not judged against a
daily one, and partial progress on a count ritual contributes proportionally.

Every ritual also tracks current and best streak, completion rate over due days,
total times logged, and a per-weekday breakdown that tells you which day you
actually keep it and which day you do not.

**Charts:** a GitHub-style heatmap of the last six months, a score trend line, a
weekday bar chart, and a month calendar you can page through. The Progress tab
rolls all of it up across the space, including how many perfect days you have had
in the last 30.

## Commentary

The app has opinions, and you choose how blunt they are. The tone setting runs
from Off through Kind and Dry to Brutal, with a separate swearing toggle that
only appears on Brutal and is off until you turn it on.

| Tone | On an empty day |
|---|---|
| Kind | "Nothing logged yet. There is still plenty of day left." |
| Dry | "Nothing logged. Bold strategy." |
| Brutal | "Zero of 3. Absolutely nothing. A masterclass." |

The lines are hand-written and picked on device: no model, no network call, no
per-message cost, and nothing the app can say that is not in
`lib/features/commentary/lines.dart`. A short memory of recent lines stops the
same joke landing twice in a row. Tests assert that the gentler tones never
swear and that profanity cannot leak while the toggle is off.

Commentary appears under the day header, on the snackbar after every log, and on
a ritual's detail screen when it has something worth saying (a lapse, a broken
streak, a score worth noticing). Reminders use the same tone, so the Cloud
Function keeps a mirrored copy of the reminder lines and reads your chosen tone
from your profile.

## Using it alone

The original version made you create or join a group before you could track
anything, and every completion needed a photo. Neither is true now.

- **A personal space is created for you** on first sign-in. It holds your
  rituals, it has one member, and it never shows invites, members or nudges.
- **Guest sign-in** needs no account at all. Tap "Start tracking" and you are in.
  Connect a Google account later from Settings and everything carries over,
  because the anonymous account is upgraded in place rather than replaced.
Photo proof still applies in a personal space. Nobody else sees it, but you do,
and that turns out to be enough.

## Using it with people

Create a shared space from Settings, then Spaces. Invite by 6-character code or
QR scan. In a shared space you also get:

- Everyone's progress on a ritual for today
- Nudges: a push notification to someone who has not logged yet
- Photo proof, when a ritual asks for it, with a shared history

Personal spaces hide all of this.

## Photo storage and peer restore

Photos are **temporary proof**, not an archive. The app is about building habits;
a photo just confirms you did the thing.

Photos live in Firebase Storage under `relay/` and are cleaned up daily, oldest
first, once the bucket nears its limit. No photo URL is guaranteed to last.

When a device cannot load a photo it writes a restore request to Firestore. The
next time any member of that space opens the app, their device checks for pending
requests and re-uploads the photo if it has it, then updates the link. Everyone
watching sees the new URL arrive live. The original poster is the most reliable
source since the photo is saved to their device at capture time. Firebase
coordinates the exchange; devices never talk to each other directly.

## Home screen widget

Android only. There is no iOS widget extension in this project, so the widget
calls are a no-op on iOS and web. The widget shows the latest photo, who posted
it, which ritual it was for and the current streak, and tapping it opens the
app. It updates both when a push arrives and when you post a photo yourself, so
it works in a personal space where no notification is ever sent.

It draws from the on-device copy of the photo rather than the remote URL, since
a widget cannot fetch over the network on its own.

**Not verified in this environment.** The widget's Kotlin and layout were
reviewed statically, every id it references resolves and the receiver is
registered in the manifest, but no Android build or device run was possible
here. Treat it as untested on device.

## Data model

```
users/{uid}                       displayName, photoUrl, groupIds, personalGroupId
groups/{groupId}                  name, memberIds, inviteCode, isPersonal, memberLimit
groups/{groupId}/rituals/{id}     title, emoji, type, target, unit, scheduleType,
                                  scheduleDays, timesPerWeek, intervalDays,
                                  reminderTime, requirePhoto, archived, colorValue
groups/{groupId}/entries/{id}     ritualId, userId, day, value, skipped, photoUrl
inviteCodes/{code}                groupId
```

Logs live in one flat `entries` collection per space rather than nested under
each ritual, so the Today screen loads a whole day with a single equality-only
query and needs no composite index. Each entry carries a `day` key in local
`yyyy-MM-dd` form, so a ritual logged at 1am lands on the day you meant. Entries
written by older versions are migrated automatically the first time a space is
opened.

## Cloud Functions

- `onEntryCreated` — notifies the other members of a shared space when someone
  posts a photo. Silent for personal spaces and for photo-less logs
- `onNudgeCreated` — delivers a nudge, then deletes the nudge doc
- `sendDailyReminders` — every 15 minutes; fires reminders using each ritual's
  stored UTC offset, respects all three schedule types, and skips anyone who has
  already logged that day
- `cleanupRelayPhotos` — daily FIFO cleanup of `relay/`, keeping usage under
  900 MB

## Tech stack

| Layer | Technology |
|---|---|
| UI | Flutter (Dart) |
| State | Riverpod |
| Theming | flex_color_scheme, light and dark with six accents |
| Icons | Lucide |
| Charts | fl_chart |
| Auth | Firebase Auth, Google and anonymous |
| Database | Cloud Firestore, offline persistence on |
| Storage | Firebase Storage |
| Notifications | Firebase Cloud Messaging |
| Backend | Cloud Functions (TypeScript) |

## Project structure

```
lib/
  app/          router, theme, app shell
  core/         providers, settings
  features/     auth, camera, home, rituals, settings, spaces, stats, streaks
  models/       Ritual, RitualEntry, Group, UserProfile
  services/     auth, group, notification, photo, restore, ritual, streak, user, widget
  shared/       avatars, download and web shims
functions/src/  Cloud Functions
test/           streak, score and model tests
```

## Setup

The Android application ID is `io.github.navknight.rituals`. It used to be the
`com.example.rituals` placeholder, which Google Play rejects and which reads as
unfinished anywhere else. **`android/app/google-services.json` has not been
regenerated for the new ID** — see [docs/PUBLISHING.md](docs/PUBLISHING.md),
which covers what that breaks and how to fix it.

1. Create a Firebase project and add Android, iOS and Web apps
2. Run `flutterfire configure` to generate `lib/firebase_options.dart`
3. In Firebase Auth, enable **Google** and **Anonymous** sign-in. Anonymous is
   what makes "Start tracking" work without an account
4. Deploy rules: `firebase deploy --only firestore:rules`
5. Deploy functions: `cd functions && npm install && firebase deploy --only functions`
6. Run: `flutter run`

## Tests

```
flutter test
```

Covers the streak rules (misses, skips, rest days, every-N-days), the habit
score formula, completion and weekday rates, photo-proof and gallery settings,
and backward-compatible parsing of documents written by earlier versions.

## Releasing

Tagging `v*` builds signed, per-ABI release APKs and attaches them to a GitHub
Release, which is what [IzzyOnDroid](https://izzyondroid.org/) tracks. Store
listing text lives in `fastlane/metadata/android/en-US/`. The full process,
including the two things that still need doing by hand, is in
[docs/PUBLISHING.md](docs/PUBLISHING.md).

## Licence

MIT, see [LICENSE](LICENSE).
