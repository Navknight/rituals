# Publishing Rituals

This covers cutting a release and getting it listed on
[IzzyOnDroid](https://izzyondroid.org/). Read the two blockers first: neither
can be done from a checkout.

---

## Blocker 1 — Firebase must learn the new application ID

The app used to ship as `com.example.rituals`, a placeholder that Google Play
rejects outright and that reads as unfinished to any reviewer. It is now
`io.github.navknight.rituals`.

`android/app/google-services.json` has had its `package_name` fields rewritten
to match, which is enough for Gradle's `google-services` plugin to find a
matching client and for the build to succeed. **It is a stopgap.** The file
still carries the `mobilesdk_app_id` and OAuth client of the old package, and
Firebase does not let you rename an existing app's package. Until this is
fixed, Google Sign-In will fail on Android, because the OAuth client is pinned
to package name plus signing certificate.

To fix it properly:

1. Firebase console → project `rituals-b3bed` → Project settings → **Add app**
   → Android, package name `io.github.navknight.rituals`.
2. Add the SHA-1 of **both** keystores to that app:
   - the debug keystore, so local `flutter run` keeps working
     (`keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`)
   - the release keystore created below — Google Sign-In will not work in
     release builds without it.
3. Download the fresh `google-services.json` and replace
   `android/app/google-services.json` wholesale.
4. Update `lib/firebase_options.dart`: the `android` entry's `appId` is still
   `1:637686614153:android:70cad962d152a471361e58`, the old app's. Re-run
   `flutterfire configure`, or copy the new `mobilesdk_app_id` across by hand.
5. Delete the old `com.example.rituals` app in Firebase once nothing depends
   on it.

## Blocker 2 — Screenshots

`fastlane/metadata/android/en-US/images/phoneScreenshots/` is empty apart from
its README. IzzyOnDroid shows these on the listing page and they have to come
off a real device. Add `1.png`, `2.png`, … before submitting.

---

## Release signing

Release builds fall back to the debug key when no keystore is configured, so
`flutter run --release` works out of the box. Those builds are **not
publishable**: IzzyOnDroid pins the signing certificate on first acceptance
(`AllowedAPKSigningKeys`) and refuses every later update signed with a
different key. Losing this keystore means losing the ability to update the
listing, so back it up somewhere durable.

Create it once:

```sh
keytool -genkey -v -keystore ~/rituals-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 -alias rituals
```

For local release builds, `android/key.properties` (gitignored):

```properties
storeFile=/absolute/path/to/rituals-release.jks
storePassword=...
keyAlias=rituals
keyPassword=...
```

For CI, add four repository secrets — the workflow fails loudly if the first
is missing rather than quietly shipping a debug-signed APK:

| Secret | Value |
| --- | --- |
| `KEYSTORE_BASE64` | `base64 -w0 ~/rituals-release.jks` |
| `KEYSTORE_PASSWORD` | store password |
| `KEY_ALIAS` | `rituals` |
| `KEY_PASSWORD` | key password |

## Cutting a release

1. Bump `version:` in `pubspec.yaml`. The part after `+` is the versionCode
   and must increase every release.
2. Add `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`. It has
   to exist **before** the tag, because IzzyOnDroid reads it per-tag, and it
   is cut off at 500 characters mid-word if longer.
3. Tag and push: `git tag v1.0.0 && git push origin v1.0.0`.

`.github/workflows/release.yml` then runs analyze and tests, builds
`--split-per-abi` (a universal Flutter + Firebase APK sits close to
IzzyOnDroid's 30 MB ceiling; each split lands well under), verifies each APK is
release-signed and not debuggable, and attaches them to the GitHub Release.

## Submitting to IzzyOnDroid

The tracker moved off GitLab in 2026 — `gitlab.com/IzzyOnDroid/repo` is
archived and read-only. Submit at
**https://codeberg.org/IzzyOnDroid/repodata/issues/new/choose**, picking the
new-app template, with an `[AppRequest]` title prefix.

Check the app against
[the inclusion policy](https://izzyondroid.org/docs/general/AppInclusionPolicy/)
first. Where Rituals stands:

| Requirement | Status |
| --- | --- |
| OSI/FSF-approved licence | MIT, in `LICENSE` |
| Source publicly accessible | GitHub |
| APK attached to a tagged release | via the workflow |
| APK under 30 MB | enforced by the workflow |
| Release-signed, not debuggable/testOnly | enforced by the workflow |
| Fastlane metadata | `fastlane/metadata/android/en-US/` |
| No ad or analytics trackers | none — no Firebase Analytics, no Crashlytics |
| Non-free components | Firebase and Google Sign-In, see below |

Firebase does not disqualify the app. IzzyOnDroid is deliberately more
permissive than upstream F-Droid and labels apps like this rather than
refusing them. Expect anti-feature flags along the lines of `NonFreeComp`,
`NonFreeDep` (Google Mobile Services) and `NonFreeNet` (Google Sign-In,
Firebase as a hosted service). What actually gets apps rejected is ad and
analytics trackers, and there are none here. Declare the Firebase dependency
in the request rather than letting the scanner find it.

Suggested request body:

> **[AppRequest] Rituals — habit tracker with photo proof**
>
> - Source: https://github.com/Navknight/rituals
> - Licence: MIT
> - Application ID: `io.github.navknight.rituals`
> - Releases: APKs attached to GitHub Releases, split per ABI, each well under 30 MB
> - Metadata: `fastlane/metadata/android/en-US/`
>
> Rituals is a habit tracker where a day only counts once a photo of the habit
> being done is attached.
>
> Declaring up front: the app uses Firebase (Auth, Firestore, Storage, Cloud
> Messaging) and Google Sign-In, so `NonFreeComp` / `NonFreeDep` / `NonFreeNet`
> flags are expected. There is no Firebase Analytics, no Crashlytics, and no ad
> or analytics SDK of any kind.

Before filing, confirm the release APK is attached, under 30 MB, and clean on
VirusTotal — reviewers check all three.
