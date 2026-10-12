# Roadmap

Each phase ends with a tagged release, updated docs and a working `docker compose up`.
Order may change. Scope inside a phase is a target, not a promise.

## Phase 0: Foundations ✅

Monorepo, `GET /health` with API-range negotiation, PocketBase server with security headers and rate
limits, SvelteKit SPA embedded in the binary, Flutter "connect to server" screen, design tokens → CSS + Dart,
OpenAPI → TS + Dart clients, Docker + Caddy deployment, CI, docs and ADRs.

## Phase 1: Server, accounts, drive ✅ (v0.2 – v0.8)

- Accounts: sign-in, sign-out, password reset (SMTP), sessions, "log out everywhere", user admin, quotas.
- 2FA: PocketBase MFA (password + email OTP), then TOTP authenticator apps at the end of the phase ([ADR 0013](adr/0013-2fa-email-otp-then-totp.md)).
- Web client only. Mobile login waits for phase 4.
- End-to-end tests in a real browser (Playwright) against the built binary.
- Drive: folders, upload (drag & drop, multiple, **resumable** via tus, [ADR 0011](adr/0011-resumable-uploads-tus.md)), download,
  rename, move, copy, trash with retention, search by name, sha256 integrity.
- Previews: images, PDF, text; thumbnails generated asynchronously.
- Sharing: public links (expiry, password, revoke), share with another user (read/edit).
- Realtime updates in the web UI across tabs/devices.
- Web shell: navigation, upload queue, keyboard shortcuts, empty states, dark mode toggle.
- First-run wizard in the web app (instead of PocketBase's installer): admin account, SMTP, storage check.
- Ops: automatic pre-migration backup, migration up/down CI on a fresh DB, release workflow publishing
  multi-arch images to GHCR, signed with provenance.

## v0.9: Install and updates ✅

One-line installer and `alcove install` (native service with automatic HTTPS, or Docker), signed
self-updates via `alcove update` and an admin "Update now" button, admin role, System page.
See [ADR 0014](adr/0014-native-install-docker-optional.md), [0015](adr/0015-signed-self-updates.md).

## Phase 2: Photos and videos (in progress)

- **v0.10** ✅ timeline by date taken (justified grid, months), photo/video viewer with details (EXIF, map
  link), favorites, video playback, HEIC, thumbnails and previews with bundled ffmpeg.
- **v0.11** ✅ albums, shared with other accounts as viewers or contributors; multi-select in the timeline.
- **v0.12** ✅ public album links (password, expiry; previews only, no location).
- **v0.13** ✅ duplicates (identical and similar photos) and timeline filters (year, camera, location).
- **v0.14** map of your photos (offline basemap, optional OpenStreetMap tiles).

Full scope: timeline by date taken, EXIF (date, camera, GPS, opt-in map), albums, favorites, shared albums,
thumbnails and previews, video transcoding (ffmpeg, optional container), Live Photos/motion photos,
HEIC/RAW support, duplicate detection. Originals are never modified. Optional face recognition module
(local, opt-in, separate container).

## Phase 3: Documents

OCR worker container (Tesseract or similar, FR + EN), full-text search (SQLite FTS5) across documents
and file names, PDF text layer, tags, scan import from the mobile camera.

## Phase 4: Mobile app and automatic backup

Mobile login, drive browser, viewer, offline favorites, **automatic photo/video backup** (background
tasks, Wi-Fi/charging constraints, resumable, deduplicated), QR-code server pairing, share sheet,
optional UnifiedPush/ntfy notifications, Play Store release (and F-Droid if feasible).

## Phase 5: Notes, calendar, contacts

Markdown notes with realtime sync, calendars (CalDAV) and contacts (CardDAV) so native apps
(DAVx⁵, iOS, Thunderbird) work out of the box.

## Phase 6: Desktop sync

Tauri app reusing the web UI, Rust folder-sync engine (two-way, conflict copies, selective sync,
resumable uploads), tray icon, autostart. Windows, macOS, Linux.

## Later / ideas

End-to-end encrypted vaults (opt-in, for folders that don't need server-side search: [ADR 0009](adr/0009-no-e2ee-in-v1.md)),
WebDAV access, external storage mounts, audit log, multiple instances per host, import from Google Photos/Drive.
