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
