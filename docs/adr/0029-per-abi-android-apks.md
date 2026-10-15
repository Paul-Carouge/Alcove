# 0029. Android: one APK per ABI, the universal APK kept

- Status: Accepted (2026-10-15). Amends ADR 0023 (release assets) and ADR 0024 (what the server serves).

## Context

The universal APK of a release weighs about 59 MB: it carries the Flutter engine and the compiled Dart
code three times (arm64-v8a, armeabi-v7a, x86_64), while a phone uses one. Every update downloads it
through the user's server. Apps up to 0.29.0 always ask their server for `alcove-android.apk`, and the web
Account page and the README link to it.

## Decision

- **Releases ship one APK per ABI** (`flutter build apk --split-per-abi`), `alcove-android-<abi>.apk` for
  `arm64-v8a`, `armeabi-v7a` and `x86_64` (about 21, 19 and 23 MB), **and still the universal
  `alcove-android.apk`**, so existing installs keep updating and a browser download works on any phone.
  `scripts/android-dist.sh` builds them, for the release workflow and `make build-apk` (or
  `ANDROID_APKS=1 make dist`). Like before, they are signed with the release key and not in `SHA256SUMS`.
- **Same versionCode everywhere.** Flutter gives per-ABI APKs `1000 × ABI + code` (a Play Store
  convention); `android/app/build.gradle.kts` resets it, and the script fails if the APKs differ. Otherwise
  a phone updated with a per-ABI APK would refuse the next universal one as a downgrade.
- **The app names its ABI.** The updater reads `Build.SUPPORTED_ABIS` and asks
  `GET /api/v1/app/android.apk?abi=<first supported ABI that has its own APK>`. The server validates `abi`
  against that list and downloads `alcove-android-<abi>.apk` from the release, falling back to the universal
  APK when `abi` is absent or unknown, when the release predates per-ABI APKs, or when GitHub cannot be
  reached but the universal APK is already cached. The server's download from GitHub is not tied to the
  phone's request, so a phone that gives up finds the APK cached when it retries. Servers up to 0.29.0
  ignore the parameter and send the universal APK.
- **Smaller code**: `--split-debug-info` (1.2 to 1.5 MB less per APK). The symbols are a CI artifact
  (`android-symbols`, kept 90 days), not a release asset; they turn release stack traces back into names
  (`flutter symbolize`). `--obfuscate` is not used: 0.13 MB more for harder debugging of open-source code.
  R8 and resource shrinking were already on (Flutter's defaults for release builds).

## Consequences

- ✅ Updates download about a third of the previous size (arm64 phones: 21 MB instead of 59 MB).
- ✅ Old apps, old servers and the web link keep working with the universal APK; phones can move between
  the universal and per-ABI APKs in both directions.
- ⚠️ A release has four APKs, and the server's `pb_data/app` may keep the universal APK plus up to three
  per-ABI ones for its version (about 125 MB at most); other versions are deleted at start.
- ⚠️ Stack traces of release builds are addresses until symbolized with the matching CI artifact.
