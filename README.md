# Alcove

**Your files, photos and documents, on your own server. Calm, fast and private.**

Alcove is a self-hosted personal cloud: a file drive, a photo and video library, and a document
archive with full-text search (OCR). Notes, calendar and contacts come later. It runs as one small
binary, deploys with one `docker compose up`, updates in realtime across your devices, and keeps your
data on hardware you control.

> **Status: early development (v0.10).** The web app has accounts with two-factor, a drive with
> resumable uploads, previews, share links and quotas, a photo and video timeline; one-command install
> and updates. Expect breaking changes before 1.0 and keep backups.

<!-- Screenshots: coming with phase 1 (drive). -->

## Why Alcove

- **One command to install, one to update.** A single Go binary built on
  [PocketBase](https://pocketbase.io), web app included, automatic HTTPS. Signed updates from the
  command line or with one click in the app.
- **Realtime.** Changes made on one device show up on the others right away (server-sent events).
- **Secure by default.** HTTPS everywhere, rate limiting, strict input validation, time-limited file
  links, optional 2FA, tokens stored in the OS keychain.
- **Your originals stay untouched.** Photos and videos are never modified. Thumbnails and previews are
  stored separately.
- **Native apps.** A web app, an Android/iOS app (Flutter), and later a desktop app with folder sync (Tauri).
- **Accessible and multilingual** (English and French) from the start.

## Quickstart (self-host)

On Linux, macOS or a Raspberry Pi, one command installs Alcove as a service (with automatic HTTPS
if you use a domain name) and prints the link to finish the setup in your browser:

```sh
curl -fsSL https://github.com/Paul-Carouge/Alcove/releases/latest/download/install.sh | sh
```

On Windows (PowerShell as administrator):
`irm https://github.com/Paul-Carouge/Alcove/releases/latest/download/install.ps1 | iex`

Updating is just as simple: `sudo alcove update`, or the **Update** button on the System page.
Prefer Docker? `docker compose up -d` works too. See [docs/SELF-HOSTING.md](docs/SELF-HOSTING.md) for
every option, backups, Tailscale and reverse proxies.

## Mobile app

The Android app will be published on the Play Store. On first launch, you enter (or scan) your
server's address, and the app checks that it is compatible before going further.

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| 0 | Foundations: monorepo, `/health`, skeleton clients, deployment, CI | ✅ v0.1.0 |
| 1 | Server, accounts and auth, **drive** (upload, folders, sharing, trash) | ✅ v0.2–v0.8 |
| – | One-command install and signed updates | ✅ v0.9 |
| 2 | Photos and videos (timeline, albums, thumbnails, EXIF) | 🚧 timeline done, albums next |
| 3 | Documents (OCR, full-text search) | |
| 4 | Mobile app and automatic photo backup | |
| 5 | Notes, calendar (CalDAV), contacts (CardDAV) | |
| 6 | Desktop app with folder sync | |

Details are in [docs/ROADMAP.md](docs/ROADMAP.md).

## Documentation

- [Architecture](docs/ARCHITECTURE.md) and [decision records](docs/adr/)
- [Design system](docs/DESIGN.md)
- [Security](docs/SECURITY.md), including how to report a vulnerability
- [Self-hosting guide](docs/SELF-HOSTING.md)
- [Contributing](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md)

## Releases

Every batch of work ships as a version: see the [CHANGELOG](CHANGELOG.md), the
[devlog](docs/devlog/) for the story behind each release, and the GitHub Releases for Docker images.

## Author

Alcove is created and maintained by **Paul Carouge**: [@Paul-Carouge](https://github.com/Paul-Carouge).

## License

Copyright © 2026 Paul Carouge.
[AGPL-3.0-only](LICENSE). If you run a modified Alcove as a service for others, you must share your changes.
