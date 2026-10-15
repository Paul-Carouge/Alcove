# 0023. Android app: signed APK in every release, http on private networks

- Status: Accepted (2026-10-12). iOS distribution is deferred (needs an Apple Developer account). Amended by [ADR 0029](0029-per-abi-android-apks.md) (per-ABI APKs).

## Context

People must be able to install the app without developer tools. The user chose a signed APK attached to
each GitHub release first; Play Store and F-Droid may follow. Many home servers are installed in "local
network" mode (`http://<machine>:8090`, ADR 0014), which release builds rejected (HTTPS only).

## Decision

- **Signing**: one Alcove release key (RSA 4096, PKCS12, alias `alcove`), kept in the GitHub secrets
  `ANDROID_KEYSTORE_B64` / `ANDROID_KEYSTORE_PASSWORD` and in the maintainer's `~/.config/alcove/`. Losing it
  means users must uninstall to update, so it is backed up like the release signing key (ADR 0015).
  Certificate SHA-256: `ee3bf775a77d20868b387f8359f9d3061e0df2fb980f87bbdbd7e49eb0f85e0f`.
- **Release workflow**: an `android` job builds `alcove-android.apk` (universal) and the release publishes
  it; `releases/latest/download/alcove-android.apk` is a stable link, shown on the web Account page. Android
  verifies updates against the signature; the APK is not in `SHA256SUMS`.
- **Plain http only on private networks**: the app accepts `http://` for private addresses (RFC 1918,
  loopback, link-local, Tailscale 100.64.0.0/10, IPv6 ULA, `.local`/`.lan`/single-label names) and shows an
  "unencrypted connection" warning; every other address must use HTTPS. Android allows cleartext at the OS
  level (`usesCleartextTraffic`) and iOS local networking (`NSAllowsLocalNetworking`); the app enforces the
  rule itself.

## Consequences

- ✅ One click from the web app to install the phone app; updates install over the previous version.
- ✅ "Local network" installs work with the release app.
- ⚠️ On http, credentials cross the home network unencrypted; the warning says so, and HTTPS (or Tailscale's
  certificates) remains the recommendation.
- ⚠️ Sideloaded APKs do not update themselves (yet); users download the new one, or the Play Store later.
