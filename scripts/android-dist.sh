#!/usr/bin/env bash
# Builds the Android APKs of a release into OUT (ADR 0023, 0029):
#   alcove-android.apk         universal: first installs from the web, and apps up to 0.29.0 update with it
#   alcove-android-<abi>.apk   one per ABI (arm64-v8a, armeabi-v7a, x86_64), about a third of the size
# Dart debug symbols go to SYMBOLS (default mobile/build/android-symbols), never next to the APKs: they
# are kept by the maintainer or CI to read stack traces (`flutter symbolize`), not published.
# Release signing needs ALCOVE_ANDROID_KEYSTORE and ALCOVE_ANDROID_KEYSTORE_PASSWORD; without them the
# APKs carry the debug key and must not be published.
#   scripts/android-dist.sh dist [SYMBOLS]
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p "${1:?usage: scripts/android-dist.sh OUT [SYMBOLS]}" "${2:-mobile/build/android-symbols}"
OUT="$(cd "$1" && pwd)"
SYMBOLS="$(cd "${2:-mobile/build/android-symbols}" && pwd)"
ABIS="arm64-v8a armeabi-v7a x86_64"

cd mobile
apks=build/app/outputs/flutter-apk
flutter pub get >/dev/null
# --split-debug-info: 1.2 to 1.5 MB less per APK (ADR 0029).
flutter build apk --release --split-debug-info="$SYMBOLS/universal"
cp "$apks/app-release.apk" "$OUT/alcove-android.apk"
flutter build apk --release --split-per-abi --split-debug-info="$SYMBOLS/per-abi"
for abi in $ABIS; do
	cp "$apks/app-$abi-release.apk" "$OUT/alcove-android-$abi.apk"
done

# All APKs must carry the same versionCode, so that a phone can move between them in both directions
# (android/app/build.gradle.kts undoes Flutter's per-ABI codes).
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$(sed -n 's/^sdk\.dir=//p' android/local.properties 2>/dev/null || true)}}"
aapt2="$(ls "$sdk"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1 || true)"
if [ -n "$aapt2" ]; then
	codes="$(for f in "$OUT"/alcove-android*.apk; do
		"$aapt2" dump badging "$f" | sed -n "s/^package: .* versionCode='\([0-9]*\)'.*/\1/p"
	done | sort -u)"
	[ "$(echo "$codes" | wc -l | tr -d ' ')" = 1 ] || { echo "APKs have different versionCodes: $codes"; exit 1; }
	echo "versionCode $codes for every APK"
else
	echo "aapt2 not found: versionCodes not checked"
	[ -z "${CI:-}" ] || exit 1 # a release must never skip this check
fi
ls -l "$OUT"/alcove-android*.apk
