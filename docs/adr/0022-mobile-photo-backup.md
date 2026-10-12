# 0022. Mobile photo backup

- Status: Accepted (2026-10-12). Extends [0021](0021-mobile-app-stack.md).

## Context

Automatic backup of the phone's photos and videos is the main reason a family installs the app. It needs
the photo library, background execution, resumable uploads and deduplication, with as little battery and
data use as possible.

## Decision

- **Library**: `photo_manager` (Apache-2.0, fluttercandies), the de-facto Flutter photo library plugin. It
  gives the original files (HEIC, RAW, videos as taken). On Android the app also asks for
  `ACCESS_MEDIA_LOCATION`, without which Android removes the GPS position from files.
- **Uploads** reuse the server's tus endpoint (ADR 0011) with a small Dart client in the app (no extra
  dependency); an interrupted upload resumes from the server's offset.
- **Deduplication**: the app sends SHA-256 fingerprints to `POST /api/v1/backup/known` and skips what the
  account already has, trash included (a photo deleted on the server is not brought back). A local state file
  (app-private storage) remembers what was handled, so a reinstall re-checks but never re-uploads.
- **When**: when the app opens or returns to the foreground, on "Back up now", and on Android about hourly in
  the background with `workmanager` (MIT, Flutter Community), constrained to unmetered networks when
  "Wi-Fi only" is on (`connectivity_plus`, BSD-3, checks it in the app). iOS background work comes later.
- **Where**: a root folder ("Phone backup", in the app's language when enabled), reused or recreated if
  deleted. Photos are never modified or deleted on the phone.
- `path_provider` and `crypto` are first-party (Flutter and Dart teams).

## Consequences

- ✅ Original quality with dates and location; no duplicates, even across reinstalls or web uploads.
- ⚠️ Three community plugins to keep current (`photo_manager`, `workmanager`, `connectivity_plus`).
- ⚠️ Hashing large videos costs some battery; it happens once per file.
- ⚠️ iPhone users must open the app for backups until iOS background tasks are added.
