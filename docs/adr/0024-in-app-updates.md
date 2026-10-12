# 0024. Mobile app updates itself from its server

- Status: Accepted (2026-10-12). Android only; iOS updates will go through the App Store.

## Context

The user wants the Android app to update "directly from itself". The app is sideloaded (ADR 0023), so no
store pushes updates. The server and the app share one version number and one API contract; the safest
version of the app is the one built with the server it talks to.

## Decision

- **The app follows its server.** `GET /api/v1/app/android` (signed-in users) returns the server's version
  and whether its release has an APK. The app offers an update when that version is newer than its own,
  checked when it opens and when it comes back to the foreground; a badge on the Account tab and a card on
  the Account screen show it.
- **The server serves the APK.** `GET /api/v1/app/android.apk?token=<file token>` downloads
  `alcove-android.apk` from the GitHub release of the running version once, keeps it in
  `pb_data/app/alcove-android-<version>.apk` and serves it. Phones never contact GitHub, which also works for
  servers reached only on a home network or Tailscale once the server itself has fetched the file. The
  release lookup is cached for an hour; development versions (`x.y.z-…`) offer nothing.
- **Android installs it.** The app downloads into its cache and opens the system installer through a
  `FileProvider` (`REQUEST_INSTALL_PACKAGES`; the user allows "install unknown apps" once). Android accepts the
  update only if it is signed with the same key as the installed app (ADR 0023), which is the integrity
  check: the APK is not in `SHA256SUMS`.
- The web Account page links to the same server-hosted APK, with the GitHub "latest" link as a fallback.

## Consequences

- Updating the server is enough: phones follow at their next launch, without a second update channel.
- Needs the server to reach GitHub once per version and the repository to be public (release assets of a
  private repository need authentication). Until then, nothing is offered.
- No downgrade: if the server is rolled back, the app keeps its newer version (`/health` `api.min/max`
  tells it whether it can still talk to the server).
- About 60 MB in `pb_data/app`; APKs of other versions are deleted when the server starts.
