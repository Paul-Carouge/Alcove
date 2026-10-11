# Changelog

All notable changes to Alcove are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/) (0.x: breaking changes can happen between minor versions).
The story behind each release is in the [devlog](docs/devlog/).

## [Unreleased]

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

[Unreleased]: https://github.com/Paul-Carouge/Alcove/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Paul-Carouge/Alcove/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Paul-Carouge/Alcove/releases/tag/v0.1.0
