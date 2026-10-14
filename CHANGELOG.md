# Changelog

All notable changes to Alcove are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/) (0.x: breaking changes can happen between minor versions).
The story behind each release is in the [devlog](docs/devlog/).

## [Unreleased]

## [0.24.0] - 2026-10-14

### Added
- **Empty the trash** in one go, with a confirmation.
- Public links to a folder show **thumbnails** of its photos and videos instead of generic icons
  (`?thumb=1` on the public file endpoint).

### Changed
- Web on phones: trash rows keep names on one line with size and date below; shared links show their
  expiry under the name instead of dropping it.

## [0.23.0] - 2026-10-14

### Added
- **Searchable PDFs**: turn a scan (PDF or image) into a copy whose text can be selected and searched in
  any PDF reader, saved next to it as `<name> (OCR).pdf`, from the Documents page or a file's actions in
  the app. `POST /api/v1/documents/{id}/searchable`. The OCR bundle gains `pdfunite`.
- **Search by tag**: typing the start of a tag's name finds the files carrying it, on the web and in the
  app; search results show tags.

### Fixed
- Mobile: uploads are no longer lost when the app is closed; they resume at the next start from where
  they stopped.

## [0.22.0] - 2026-10-14

### Added
- **Tags** on files and folders ("Invoices", "Taxes"…), each with a colour: set them from the Tags action
  on the web or the ⋯ menu in the app, create, rename, recolour or delete them on the spot. They show as
  chips in Files and Documents, and the Documents page filters by tag. Deleting a tag keeps the files.

### Fixed
- Mobile: the file action sheets scroll instead of overflowing on small screens.

## [0.21.0] - 2026-10-13

### Added
- **Mobile file management**: a + button in Files to create a folder, **send files** from the phone and
  **scan a document** (edge detection and cropping, several pages, one PDF whose text your server reads by
  OCR); rename, move and move to the trash (with Undo) from the ⋯ button or a long press. Uploads show their
  progress at the bottom of Files ([ADR 0026](docs/adr/0026-mobile-files-and-scanning.md)).

### Fixed
- Web: the upload panel no longer stays open over the page once everything is uploaded; it folds after a
  moment and can be closed from its header.

## [0.20.0] - 2026-10-13

### Added
- **Documents**: Alcove reads the text of your PDFs and text files and, with OCR, of scanned PDFs and
  screenshots (images without camera information), so you can search them. A **Documents** page lists them
  with an excerpt, filters, a live reading status and the full text ready to copy
  ([ADR 0025](docs/adr/0025-documents-and-ocr.md)).
- **Search inside documents**, on the web and in the mobile app (new search screen in Files): file and
  folder names first, then documents whose text matches, with the matching words highlighted. Accents and
  case are ignored; words match as prefixes. `GET /api/v1/search`.
- **OCR tools shipped like ffmpeg**: Tesseract (French and English) and poppler. `alcove install` offers a
  signed bundle on Linux (about 25 MB, `--no-ocr` to skip), updates keep it current, administrators can
  install it from the System page, and the Docker image includes it. Homebrew or winget on macOS and Windows.
- System page: a Documents and OCR card (tools, progress, turn OCR off). `alcove status` shows the OCR tools.

### Changed
- Web: dropdowns (language, photo filters, album roles) are drawn by Alcove instead of the browser, with
  full keyboard support; checkboxes, radio buttons and switches use the design tokens.
- The ffmpeg bundle installer became a generic tool-bundle installer (no change for existing installs).

## [0.19.0] - 2026-10-12

### Added
- **The Android app updates itself from your server**: after a server update, the app shows a badge on
  Account and an **Update now** button; the server serves the APK of its own version (fetched once from its
  release, kept in `pb_data/app`) and Android installs it only if it has the same signature
  ([ADR 0024](docs/adr/0024-in-app-updates.md)). `GET /api/v1/app/android` and `/api/v1/app/android.apk`.
- Mobile: an **Albums** tab.

### Changed
- **Mobile redesign**: large collapsing titles, grouped lists, rounded photo tiles that fade in, month
  headers that stay visible while scrolling, a profile header and server badge on Account, a progress ring
  for backup, an immersive photo viewer (tap to hide the controls) and a branded sign-in. Buttons now use
  the Inter font like the rest of the app.
- Web: the Account page downloads the app from your server, with its version. On phones the photo tools
  fit in one scrolling row and the files search takes the full width.

## [0.18.1] - 2026-10-12

### Fixed
- **HEIC photos from phones** got no thumbnail: phone cameras store them as a grid of tiles, which the
  thumbnail step did not handle ("Invalid argument"). Their date, camera and size are now read too, including
  from phones that place the metadata unusually (e.g. OPPO). Photos that had failed are processed again at
  the next start.

## [0.18.0] - 2026-10-12

### Added
- **Android app in every release**: `alcove-android.apk`, signed with the Alcove release key, attached to each
  GitHub release; the web app links to it (Account → Alcove on your phone) ([ADR 0023](docs/adr/0023-android-distribution.md)).
- Mobile: albums (yours and shared with you) and album view; move your own photos to the trash from the viewer.

### Changed
- The mobile app accepts plain `http://` addresses on private networks (home network, `.local`, Tailscale),
  with an "unencrypted connection" warning, so servers installed in "local network" mode work with the
  release app. Other addresses still require HTTPS.
- Favorites can only be toggled on your own photos in the mobile viewer.

## [0.17.0] - 2026-10-12

### Added
- **Users** page for administrators (account menu): accounts with storage use and two-factor status; create
  an account with a generated password to hand over, change name, quota and role, reset a password, delete
  an account and everything it owns (typed confirmation). No need for the PocketBase console anymore.
- **Account** page: change your name and password (you are signed out everywhere and sign in again).
- **Photos**: favorite or move to trash several photos from the selection; move to trash from the viewer.
- **Search** in Files: find files and folders by name across all folders.
- API: `GET/POST /api/v1/admin/users`, `PATCH/DELETE /api/v1/admin/users/{id}`.

### Changed
- Administrators cannot demote or delete themselves, and a server always keeps one administrator.

## [0.16.0] - 2026-10-12

### Added
- **Automatic photo backup** in the mobile app: the phone's photos and videos are copied to a "Phone backup"
  folder in original quality (HEIC, RAW, videos as taken, with dates and locations). Runs when the app opens,
  with "Back up now", and about every hour in the background on Android. Options: include videos, Wi-Fi only.
- No duplicates: files the server already has (even uploaded from the web, or before a reinstall) are
  skipped; interrupted uploads resume ([ADR 0022](docs/adr/0022-mobile-photo-backup.md)).
- API: `POST /api/v1/backup/known`.
- `make dev DEV_HOST=0.0.0.0` to try the app on a phone against a development server.

## [0.15.0] - 2026-10-12

Phase 4 (mobile app) begins.

### Added
- **Mobile app**: sign-in after the server check, with the same second factors as the web (authenticator
  app, recovery code or email code); the session is kept in the Keychain / Keystore and refreshed at start.
- Photos tab: timeline by month with video durations and favorites, pull to refresh, endless scrolling;
  full-screen viewer with swipe, pinch to zoom, video playback, favorite and details.
- Files tab: folders and files, opened in the system browser. Account tab with sign-out and the credit.
- [ADR 0021](docs/adr/0021-mobile-app-stack.md): PocketBase Dart SDK and official Flutter packages only.

### Fixed
- The mobile connect screen's Continue button did nothing.

## [0.14.0] - 2026-10-12

### Added
- **Map** (Photos → Map): your photos where they were taken, grouped into thumbnails that split as you
  zoom; click to open them in the viewer. "Show on map" from the viewer.
- A world map built into Alcove (Natural Earth countries and cities): works offline, sends nothing outside.
- Administrators can enable detailed OpenStreetMap tiles on the System page; the security policy allows
  them only while enabled ([ADR 0020](docs/adr/0020-photo-map.md)).
- API: `GET /api/v1/photos/locations`, `GET /api/v1/map/config`, `PUT /api/v1/admin/map`.
- Third-party notices in `docs/THIRD-PARTY.md`.

### Changed
- Load errors say "this page" instead of "this folder" outside the drive.

## [0.13.0] - 2026-10-12

### Added
- **Duplicates** (Photos → Duplicates): identical copies and visually similar photos (resized, recompressed,
  bursts), with the best copy suggested. Move the others to the trash per group or all at once, or mark a
  group as "not duplicates". Nothing is deleted automatically.
- **Filters** in Photos: year, camera and "with a location", built from your own library.
- API: `GET /api/v1/photos/duplicates`, `POST /api/v1/photos/duplicates/dismiss`, `GET /api/v1/photos/facets`.

### Changed
- Every photo gets a perceptual fingerprint, computed in the background (existing libraries included).

### Fixed
- Changing a filter while the timeline was loading could show the previous results.

## [0.12.0] - 2026-10-12

### Added
- **Public album links**: album owners create a link (optional password and expiry) from the album menu,
  for people without an account. Visitors see the album as it is now, in the same photo grid and viewer.
  Links are listed and revoked on the Shared page ([ADR 0019](docs/adr/0019-public-album-links.md)).
- API: `POST /api/v1/shares` accepts `album`; `GET /api/v1/public/shares/{token}/media/{mediaId}/{variant}`.

### Security
- Album links expose no location, camera or lens data, and serve photos only as re-encoded previews
  without metadata; original photos are never served. Videos still play from the original file.

## [0.11.1] - 2026-10-12

### Fixed
- Photos and videos uploaded before v0.10 now appear in Photos: they are indexed at the next start.
  Servers updated from v0.9 showed an empty Photos page.

## [0.11.0] - 2026-10-12

### Added
- **Albums**: create albums, add photos and videos from the timeline (new multi-select mode) or the viewer,
  choose a cover, rename, delete.
- **Shared albums**: share an album with other accounts of the server, each person either *can view* or
  *can add photos* (their own). Participants see shared albums in their Albums page, can play videos and
  download originals, and can leave; removing a contributor also removes the photos they added
  ([ADR 0018](docs/adr/0018-albums-and-sharing-between-accounts.md)).
- API: `GET /api/v1/albums`, `/albums/{id}/items`, `/albums/{id}/people`, `POST /albums/{id}/leave`,
  `GET /api/v1/users/lookup`, `GET /api/v1/media/{id}/original`.

### Changed
- Every photo now gets its own thumbnail and preview, made without ffmpeg for JPEG, PNG, GIF and WebP when
  it is missing; existing photos are processed again once at startup.
- The selection bar sits at the top of the page, clear of the upload panel.

### Security
- Drive files stay readable by their owner only; shared photos are served through the album's rules,
  checked on every request.

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

[Unreleased]: https://github.com/Paul-Carouge/Alcove/compare/v0.18.1...HEAD
[0.18.1]: https://github.com/Paul-Carouge/Alcove/compare/v0.18.0...v0.18.1
[0.18.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.17.0...v0.18.0
[0.17.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.16.0...v0.17.0
[0.16.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.15.0...v0.16.0
[0.15.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.14.0...v0.15.0
[0.14.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.12.0...v0.13.0
[0.12.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.11.1...v0.12.0
[0.11.1]: https://github.com/Paul-Carouge/Alcove/compare/v0.11.0...v0.11.1
[0.11.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.10.2...v0.11.0
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
