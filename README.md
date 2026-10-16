# Alcove

**Your files, photos and documents, on your own server. Calm, fast and private.**

Alcove is a self-hosted personal cloud: a file drive, a photo and video library, and a document
archive with full-text search (OCR). Notes and a calendar come later. It runs as one small binary,
installs with one command, updates in realtime across your devices, and keeps your data on hardware you
control: a spare PC at home, a Raspberry Pi or a small cloud server.

> **Status: early development (v0.25).** Working today:
> - **Files**: drive with resumable uploads, folders, tags, previews, share links (password, expiry),
>   ZIP downloads, trash, quotas, search inside documents.
> - **Photos**: timeline with memories, albums shared between accounts or by public link, map,
>   duplicates, favorites, a full-screen viewer with zoom and slideshow; HEIC and videos.
> - **Documents**: text of PDFs, scans and screenshots (OCR, French and English), searchable PDF copies.
> - **Android app**: photos, albums, files (send, scan, organise), automatic photo backup, search,
>   updates itself from your server.
> - **Running it**: one-command install, signed updates from the command line or the app, two-factor,
>   accounts and quotas, English and French.
>
> Expect breaking changes before 1.0 and keep backups.

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

### Let an AI assistant do it

Using Claude, ChatGPT or another assistant with access to your server? Copy the ready-made prompt in
[docs/AI-INSTALL.md](docs/AI-INSTALL.md) and paste it into the chat: it gives the assistant everything it
needs to install, update, back up or troubleshoot Alcove (real commands and flags, file locations, the app,
common mistakes), and asks it to explain each command before running it.

## Mobile app

Android and iOS (Flutter). On first launch you enter your server's address; the app checks that it is
compatible, then you sign in (two-factor included), browse your photos, videos and files, and turn on
**automatic photo backup** (original quality, no duplicates, Wi-Fi only if you want). In Files you can send
files from the phone, **scan documents** into PDFs (read by OCR on your server), create folders, rename,
move, trash and search inside documents.

**Android:** download `alcove-android.apk` from the [latest release](https://github.com/Paul-Carouge/Alcove/releases/latest)
(or from the web app: Account → Alcove on your phone). It works on any phone; the release also has smaller
APKs per processor type, e.g. `alcove-android-arm64-v8a.apk` for most recent phones. It then
**updates itself from your server**: update Alcove and phones offer the matching version at their next
launch. The iPhone app comes later.

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| 0 | Foundations: monorepo, `/health`, skeleton clients, deployment, CI | ✅ v0.1.0 |
| 1 | Server, accounts and auth, **drive** (upload, folders, sharing, trash) | ✅ v0.2–v0.8 |
| – | One-command install and signed updates | ✅ v0.9 |
| 2 | Photos and videos (timeline, albums, thumbnails, EXIF) | 🚧 timeline, albums, links, duplicates, filters, map and Google Photos import done |
| 3 | Documents (OCR, full-text search) | 🚧 PDF text, OCR of scans and screenshots, full-text search done |
| 4 | Mobile app and automatic photo backup | 🚧 sign-in, photos, albums, file management, scanning, automatic backup and in-app updates done |
| 5 | Notes, calendar (CalDAV) | |
| 6 | Desktop app with folder sync | |

Details are in [docs/ROADMAP.md](docs/ROADMAP.md).

## Documentation

- [Architecture](docs/ARCHITECTURE.md) and [decision records](docs/adr/)
- [Design system](docs/DESIGN.md)
- [Security](docs/SECURITY.md), including how to report a vulnerability
- [Self-hosting guide](docs/SELF-HOSTING.md)
- [Install with an AI assistant](docs/AI-INSTALL.md): a prompt to paste into your assistant
- [Contributing](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md)

## Releases

Every batch of work ships as a version: see the [CHANGELOG](CHANGELOG.md), the
[devlog](docs/devlog/) for the story behind each release, and the GitHub Releases for Docker images.

## Author

Alcove is created and maintained by **Paul Carouge**: [@Paul-Carouge](https://github.com/Paul-Carouge).

## License

Copyright © 2026 Paul Carouge.
[AGPL-3.0-only](LICENSE). If you run a modified Alcove as a service for others, you must share your changes.
