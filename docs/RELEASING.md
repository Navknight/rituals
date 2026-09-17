# Releasing

## 1. Generate a signing key

```
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep `upload-keystore.jks` outside the repo. Losing it means you can never
update the app under the same signature again.

## 2. Encode the keystore

```
base64 -w0 upload-keystore.jks
```

Copy the output; this becomes the `KEYSTORE_BASE64` secret.

## 3. Add GitHub secrets

Settings > Secrets and variables > Actions > New repository secret. Create:

- `KEYSTORE_BASE64` — output of the base64 command above
- `KEYSTORE_PASSWORD` — the keystore password
- `KEY_ALIAS` — `upload` (or whatever alias you used)
- `KEY_PASSWORD` — the key password

## 4. Cut a release

1. Bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2`)
2. Commit the change
3. `git tag v1.0.1 && git push --tags`

The `release.yml` workflow builds signed APKs (split per ABI plus a
universal build) and attaches them to a GitHub Release automatically.
It also builds the web app and deploys it to Firebase Hosting, which needs a
`FIREBASE_SERVICE_ACCOUNT` secret: the JSON key of a service account with the
Firebase Hosting Admin role (Firebase console > Project settings > Service
accounts > Generate new private key). Installed Android apps notice the new
GitHub release on their next open and offer the download.

## Invite links

Invite links are `https://rituals-b3bed.web.app/join/<code>`. Android opens them
in the app instead of the browser only while
`https://rituals-b3bed.web.app/.well-known/assetlinks.json` lists the signing
key's SHA-256 fingerprint, which `web/assetlinks.json` does. Two things keep
that path working and both live in `firebase.json`: the rewrite from
`/.well-known/assetlinks.json`, and `"appAssociation": "NONE"` — left on `AUTO`,
Firebase serves its own generated (empty) file there instead. Signing with a
different key means regenerating the fingerprint:

```
keytool -list -v -keystore upload-keystore.jks -alias upload | grep SHA256
```

## Submitting to IzzyOnDroid

Open a request at the [IzzyOnDroid repo issue tracker](https://gitlab.com/IzzyOnDroid/repo/-/issues).
Requirements:

- An OSS license (this repo uses GPL-3.0, see `LICENSE`)
- A GitHub release with a built APK attached
- Fastlane metadata under `fastlane/metadata/android/en-US/`

The listing will be tagged with `NonFreeDep` and `NonFreeNet` anti-features
because the app depends on Firebase and Google Sign-In, both proprietary
services. This is expected and does not block inclusion.

## Obtainium

No infrastructure needed. Users add the app in Obtainium by pasting this
repo's GitHub URL; Obtainium tracks new tags and installs releases directly.

## Why not F-Droid's main repo

F-Droid's official repo only distributes apps it builds itself from fully
free source, and this app depends on Firebase and Google Play Services,
which are proprietary. That rules out the main F-Droid repo; IzzyOnDroid
(which redistributes existing release APKs rather than rebuilding from
source) and Obtainium are used instead.
