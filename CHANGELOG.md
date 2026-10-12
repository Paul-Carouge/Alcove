# Changelog

All notable changes to Alcove are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/) (0.x: breaking changes can happen between minor versions).
The story behind each release is in the [devlog](docs/devlog/).

## [Unreleased]

## [0.10.2] - 2026-10-12

### Added
- Native Linux installs get Alcove's own recent ffmpeg (8.1, from Alpine packages, with its libraries)
  when the system one is missing or older than 7.1, so iPhone HEIC photos get thumbnails on Debian 12
  and Ubuntu 24.04. Releases ship it for amd64, arm64 and armv7, signed like the binary; it lives next to
  the binary and never changes the system ([ADR 0017](docs/adr/0017-ffmpeg-bundle-for-native-linux.md)).
- `alcove status` shows which ffmpeg is used.

### Changed
- `alcove update`, the in-app update and `sudo alcove update` on an up-to-date server keep that ffmpeg
  current. Servers installed earlier: run `sudo alcove update` once after updating to 0.10.2.

## [0.10.1] - 2026-10-12

### Fixed
- HEIC photos on servers with ffmpeg older than 7.1 (Debian 12, Ubuntu 24.04) now fail with a clear
  message instead of "Invalid data found when processing input". The Docker image (ffmpeg 8.1) was not
  affected.

## [0.10.0] - 2026-10-12

Phase 2 (photos and videos) begins.

### Added
- **Photos**: every image and video added anywhere in Files appears in a timeline sorted by date taken,
  grouped by month, in justified rows; infinite scroll and live updates.
- Photo and video viewer: full-screen preview or playback, keyboard navigation, details panel (date,
  file, dimensions, duration, camera, lens, exposure, location with an OpenStreetMap link), download.
- Favorites (heart on hover or in the viewer) and filters: All, Favorites, Videos.
- Server photos pipeline: EXIF metadata, `ffprobe` for videos and HEIC, thumbnails (360 px) and
  previews (1600 px) rendered by `ffmpeg` in the background; pending work resumes at boot, failures
  are retried daily. API: `PUT /api/v1/media/{mediaId}/favorite`.
- The Docker image now includes ffmpeg 8 (Alpine 3.24 base, still non-root).

### Changed
- Photo sizes come from the image header rather than EXIF, which goes stale after edits.

## [0.9.1] - 2026-10-12

### Fixed
- Builds made from a clone without tags reported a commit hash as their version, so updates were
  never offered; they now report `0.0.0-dev` and are offered every release.

## [0.9.0] - 2026-10-12

### Added
- One-line installers (`install.sh`, `install.ps1`) and `alcove install`: public domain with automatic
  HTTPS, local network/Tailscale, or behind a reverse proxy; dedicated service user; systemd, OpenRC,
  launchd or Windows startup task; offers to install ffmpeg; prints the setup link.
- `alcove update` (verify, back up, install, restart, automatic rollback), `alcove rollback`,
  `alcove status`, `alcove uninstall`, `alcove backup`.
- Releases ship binaries for Linux (amd64, arm64, armv7), macOS (amd64, arm64) and Windows (amd64),
  with SHA256SUMS signed by an Ed25519 key.
- Administrators: `role` on accounts, daily update check, update banner, System page with release
  notes and an Update button (native installs); `deploy/update.sh` for Docker.
- `ALCOVE_UPDATE_CHECK`, `ALCOVE_UPDATE_URL`, `ALCOVE_INSTALL_MODE`; `--env-file` for services.

### Security
- Updates are refused unless the signature and checksum verify; the database is backed up first.
- Hardened systemd unit (dedicated user, read-only system, only the data directory writable).

## [0.8.0] - 2026-10-12

Phase 1 (server, accounts, drive) is complete.

### Added
- First-run setup wizard at `/setup`: create the administrator (admin console and app account),
  optionally configure and test email (SMTP), check that storage is writable, then sign straight in.
- Every page leads to the wizard until an administrator exists.
- `ALCOVE_SETUP_TOKEN` to preset the setup token for automated deployments.

### Changed
- The first-launch log line links to the wizard instead of PocketBase's installer.

### Security
- The wizard requires the one-time token, compares it in constant time, is rate limited and
  stops working once setup is complete; concurrent completions cannot create two administrators.

## [0.7.0] - 2026-10-12

### Added
- Two-factor authentication with an authenticator app (TOTP): QR code or manual key, confirmation
  with a first code, 10 single-use recovery codes (copy or download), regeneration and turning off.
- Sign-in asks for the 6-digit code (or a recovery code) when two-factor is on.
- Security page, reachable from the account menu.
- `ALCOVE_SECRET_KEY` to encrypt sensitive data at rest (a key file is generated otherwise).

### Security
- The code is requested only after the password is verified, so two-factor status never leaks.
- Codes cannot be reused (per-step replay protection); email one-time codes cannot bypass TOTP.
- Secrets are encrypted (AES-GCM), recovery codes stored as hashes; routes are rate limited.

## [0.6.0] - 2026-10-12

### Added
- Per-user storage quotas set by the administrator (`quota_bytes`, 0 = unlimited), trash included.
- Storage meter in the sidebar with an "almost full" warning above 90%.
- `GET /api/v1/me/usage` (used, trash, quota).
- Uploads that do not fit are refused up front and shown as "Not enough space".

### Security
- Users cannot change their own quota (users update rule).

## [0.5.0] - 2026-10-12

### Added
- Public share links for files and folders: optional expiry (1 day to 1 year) and password,
  revocation, a public page at `/s/{token}` with preview, download and folder browsing.
- "Shared" page listing your active links.
- Release tooling: `make release V=x.y.z`, CHANGELOG and devlog, tagged releases publishing
  multi-architecture images to GHCR.
- Author credit (Paul Carouge) in the app, README and AUTHORS.

### Security
- Link tokens are 256-bit, shown once, stored as SHA-256; secrets are hidden fields.
- Password attempts limited to 10 per minute per IP; unlock tokens are signed per share.
- Folder links cannot escape their subtree; public pages are `noindex` and `no-referrer`.

### Fixed
- A file finishing its upload while its folder was loading could vanish from the list.

## [0.4.0] - 2026-10-11

### Added
- Multi-select (checkboxes, shift ranges, select all) with bulk move and trash.
- "Move to…" dialog with a folder browser, and drag-to-move onto folders and breadcrumbs.
- Thumbnails (JPEG, PNG, GIF, WebP), a remembered list/grid layout and a full-screen viewer
  for images, text, video, audio and PDF with keyboard navigation.

### Security
- Inline display only for a passive-type allowlist, with a sandboxing CSP; HTML and SVG
  always download.

### Fixed
- Checkboxes appeared unchecked on selected rows; grid and viewer images overflowed.

## [0.3.0] - 2026-10-11

### Added
- Drive: folders, breadcrumbs, natural sort, live updates across tabs and devices.
- Resumable uploads (tus) with a progress panel, retry, cancel and drag and drop;
  name conflicts are renamed automatically.
- Rename, download under the real file name, trash with restore and a 30-day purge.
- Server-side invariants: size, type and SHA-256 computed from content, cycle-free moves,
  case-insensitive unique names per folder.

### Fixed
- Server startup panic from a route conflict between uploads and the web app.
- Unknown `/api/` routes returned the web app instead of a JSON 404.
- Upload URLs stay HTTPS behind the reverse proxy.

## [0.2.0] - 2026-10-11

### Added
- Sign-in with optional email one-time code (MFA), password reset, protected routes.
- Modern app shell: sidebar, account menu, light/dark/system theme, split sign-in page.
- Base UI components built on the design tokens; Playwright end-to-end tests with
  automated accessibility checks (axe, WCAG 2.2 AA).

### Security
- Public sign-up disabled: accounts are created by the administrator.

## [0.1.0] - 2026-10-11

### Added
- Monorepo foundations: PocketBase server with `/health`, SvelteKit web app embedded in the
  binary, Flutter "connect to your server" screen, design tokens shared by web and mobile,
  OpenAPI contract with generated TypeScript and Dart clients.
- Docker image (distroless) and docker compose with Caddy for automatic HTTPS.
- CI, pre-commit hooks, Conventional Commits, Renovate; documentation and ADRs.

### Fixed
- Blank web page caused by conflicting Content Security Policies.
- The server no longer opens a browser tab on first launch.

[Unreleased]: https://github.com/Paul-Carouge/Alcove/compare/v0.10.2...HEAD
[0.10.2]: https://github.com/Paul-Carouge/Alcove/compare/v0.10.1...v0.10.2
[0.10.1]: https://github.com/Paul-Carouge/Alcove/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.9.1...v0.10.0
[0.9.1]: https://github.com/Paul-Carouge/Alcove/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Paul-Carouge/Alcove/releases/tag/v0.1.0
