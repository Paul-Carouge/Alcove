# Alcove

**Your files, photos and documents, on your own server. Calm, fast and private.**

Alcove is a self-hosted personal cloud: a file drive, a photo and video library, and a document
archive with full-text search (OCR). Notes, calendar and contacts come later. It runs as one small
binary, deploys with one `docker compose up`, updates in realtime across your devices, and keeps your
data on hardware you control.

> **Status: early development.** The foundations are in place (server, web and mobile skeletons,
> deployment, CI). No user-facing feature works yet. Don't store anything important in it yet.

<!-- Screenshots: coming with phase 1 (drive). -->

## Why Alcove

- **One binary, one command.** A Go server built on [PocketBase](https://pocketbase.io) with the
  web app embedded. Caddy provides automatic HTTPS.
- **Realtime.** Changes made on one device show up on the others right away (server-sent events).
- **Secure by default.** HTTPS everywhere, rate limiting, strict input validation, time-limited file
  links, optional 2FA, tokens stored in the OS keychain.
- **Your originals stay untouched.** Photos and videos are never modified. Thumbnails and previews are
  stored separately.
- **Native apps.** A web app, an Android/iOS app (Flutter), and later a desktop app with folder sync (Tauri).
- **Accessible and multilingual** (English and French) from the start.

## Quickstart (self-host)

You need Docker with Compose, and a domain name pointing to your server with ports 80 and 443 open.

```sh
git clone https://github.com/Paul-Carouge/Alcove.git && cd Alcove/deploy
cp ../.env.example .env && nano .env      # set ALCOVE_DOMAIN and ALCOVE_ACME_EMAIL
docker compose up -d
```

Then run `docker compose logs alcove`, open the one-time setup link it prints, and create the
administrator account. To try it on your machine, set `ALCOVE_DOMAIN=localhost`.

Backups, updates, Tailscale and reverse-proxy setups: see [docs/SELF-HOSTING.md](docs/SELF-HOSTING.md).

## Mobile app

The Android app will be published on the Play Store. On first launch, you enter (or scan) your
server's address, and the app checks that it is compatible before going further.

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| 0 | Foundations: monorepo, `/health`, skeleton clients, deployment, CI | ✅ done |
| 1 | Server, accounts and auth, **drive** (upload, folders, sharing, trash) | ⏳ next |
| 2 | Photos and videos (timeline, albums, thumbnails, EXIF) | |
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

## License

[AGPL-3.0-only](LICENSE). If you run a modified Alcove as a service for others, you must share your changes.
