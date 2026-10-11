# Roadmap

Each phase ends with a tagged release, updated docs and a working `docker compose up`.
Order may change. Scope inside a phase is a target, not a promise.

## Phase 0: Foundations ✅

Monorepo, `GET /health` with API-range negotiation, PocketBase server with security headers and rate
limits, SvelteKit SPA embedded in the binary, Flutter "connect to server" screen, design tokens → CSS + Dart,
OpenAPI → TS + Dart clients, Docker + Caddy deployment, CI, docs and ADRs.

## Phase 1: Server, accounts, drive

- Accounts: sign-in, sign-out, password reset (SMTP), sessions, "log out everywhere", user admin, quotas.
- 2FA: expose PocketBase MFA (password + email OTP). **Decide** on TOTP authenticator apps (custom).
- **Decide** the web token storage (SDK `localStorage` vs HttpOnly cookie, see ARCHITECTURE).
- Drive: folders, upload (drag & drop, multiple, **resumable**, decide tus vs chunked), download,
  rename, move, copy, trash with retention, search by name, sha256 integrity.
- Previews: images, PDF, text; thumbnails generated asynchronously.
- Sharing: public links (expiry, password, revoke), share with another user (read/edit).
- Realtime updates in the web UI across tabs/devices.
- Web shell: navigation, upload queue, keyboard shortcuts, empty states, dark mode toggle.
- First-run wizard in the web app (instead of PocketBase's installer): admin account, SMTP, storage check.
- Ops: automatic pre-migration backup, migration up/down CI on a fresh DB, release workflow publishing
  multi-arch images to GHCR, signed with provenance.

## Phase 2: Photos and videos

Timeline by date taken, EXIF (date, camera, GPS, opt-in map), albums, favorites, shared albums,
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
