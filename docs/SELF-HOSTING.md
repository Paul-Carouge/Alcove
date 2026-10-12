# Self-hosting

> Alcove is in early development (drive and photo timeline work). Keep backups and expect breaking changes before 1.0.

## Requirements

- Linux (x86-64, ARM64 or ARMv7: Raspberry Pi 3+), macOS (Intel or Apple Silicon) or Windows 10/11 (x86-64).
  1 GB RAM minimum. Disk: your data plus about 10% (thumbnails and previews of photos and videos).
- Linux: systemd (Debian, Ubuntu, Fedora, Arch…) or OpenRC (Alpine).
- For public HTTPS: a domain name whose DNS points to the machine, with ports **80 and 443** reachable.
  For private use only, choose "local network" during install and see [Tailscale](#private-access-with-tailscale).

## Install (recommended)

```sh
curl -fsSL https://github.com/Paul-Carouge/Alcove/releases/latest/download/install.sh | sh
```

The script downloads the binary for your system, checks its checksum and runs `alcove install`, which
asks how you will reach Alcove:

1. **From the internet with a domain name**: automatic HTTPS (Let's Encrypt), ports 80/443.
2. **On your local network or Tailscale**: `http://<machine>:8090`.
3. **Behind your own reverse proxy**: listens on `127.0.0.1:8090`.

It then creates a dedicated system user (Linux), installs the service (systemd, OpenRC, launchd or a
Windows startup task), offers to install ffmpeg, starts Alcove and prints the setup link.

**ffmpeg** is needed for video and HEIC thumbnails (the Docker image includes it). Without it, JPEG, PNG
and WebP photos still work; videos and HEIC files show without a thumbnail. If you install ffmpeg later,
those files are processed again within a day (failed items are retried daily).

Non-interactive (scripts, cloud-init):

```sh
curl -fsSL …/install.sh | sh -s -- --mode public --domain cloud.example.com --yes
```

Windows: in PowerShell as administrator, `irm https://github.com/Paul-Carouge/Alcove/releases/latest/download/install.ps1 | iex`.

Where things live:

| | Linux | macOS (sudo) | macOS (user) | Windows |
|---|---|---|---|---|
| Binary | `/var/lib/alcove/bin/alcove` (+ `/usr/local/bin/alcove`) | `/usr/local/lib/alcove/alcove` | `~/Library/Application Support/Alcove/bin` | `%ProgramFiles%\Alcove` |
| Data | `/var/lib/alcove` | `/usr/local/var/alcove` | `~/Library/Application Support/Alcove` | `%ProgramData%\Alcove` |
| Config | `/etc/alcove/alcove.env` | `/usr/local/etc/alcove/alcove.env` | same folder as data | `%ProgramData%\Alcove\alcove.env` |

Useful commands: `alcove status`, `sudo alcove update`, `sudo alcove rollback`, `sudo alcove uninstall`
(keeps data; `--purge` removes it).

## Install with Docker (alternative)

```sh
git clone https://github.com/Paul-Carouge/Alcove.git && cd Alcove/deploy
cp ../.env.example .env && chmod 600 .env
nano .env                     # ALCOVE_DOMAIN=cloud.example.com, ALCOVE_ACME_EMAIL=you@example.com
docker compose up -d
```

**First-run setup:** run `docker compose logs alcove` and open the printed link
(`https://<domain>/setup?token=…`). The wizard creates the administrator (admin console **and** app
account, same credentials), lets you configure and test email (SMTP), and checks that storage is
writable. The token works until setup is complete; a restart prints a new one. For automated
deployments, preset it with `ALCOVE_SETUP_TOKEN` (16+ characters) and open `https://<domain>/setup`.

Check it is up: `curl https://<domain>/health`.

**Users and quotas:** create accounts in the admin UI (`users` collection → New record). Set
`quota_bytes` to limit a user's storage (trash included), e.g. `53687091200` for 50 GB; `0` means
unlimited. Set `role` to `admin` to give access to the System page. Users see their usage in the
sidebar and cannot change their own quota or role.

**Recommended next steps** in the admin UI (`https://<domain>/_/`): Settings → Backups (schedule),
and turn on two-factor in the app (account menu → Security).

### Configuration

All settings are environment variables in `deploy/.env` (documented in [`.env.example`](../.env.example)):

| Variable | Default | Purpose |
|---|---|---|
| `ALCOVE_DOMAIN` | required | Public hostname. Used by Caddy and in links |
| `ALCOVE_ACME_EMAIL` | required | Let's Encrypt account email |
| `ALCOVE_STORAGE` | `local` | `local` or `s3` |
| `ALCOVE_S3_*` | | Endpoint, region, bucket, keys, path style (when `s3`) |
| `ALCOVE_MODULES` | empty | Optional modules (`ocr`, `faces`). Not implemented yet |
| `ALCOVE_UPDATE_CHECK` | `true` | Daily check for new releases (contacts GitHub); `false` to disable |
| `ALCOVE_SETUP_TOKEN` | random | Presets the first-run wizard token (16+ chars); the link is printed in the logs otherwise |
| `ALCOVE_SECRET_KEY` | generated | Encrypts two-factor secrets (32+ chars). If unset, `pb_data/secret.key` is created: keep it in your backups |
| `ALCOVE_TRUSTED_PROXY_HEADER` | set by compose | Header with the real client IP |
| `ALCOVE_VERSION` | `latest` | Image tag to run |

Invalid values stop the server at boot with an explicit message (`docker compose logs alcove`).
Rate limits are tuned in the admin UI (Settings → Rate limits).

## Behind an existing reverse proxy

If you already run nginx, Traefik or another proxy, skip Caddy and expose Alcove on localhost only:

```sh
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d alcove
```

`docker-compose.local.yml` publishes `127.0.0.1:8090`. Then configure your proxy to:
- terminate TLS and redirect HTTP→HTTPS (add HSTS),
- forward to `http://127.0.0.1:8090`, setting `X-Forwarded-For` (and `X-Forwarded-Proto`),
- **disable response buffering** (needed for realtime `/api/realtime`), e.g. nginx `proxy_buffering off;`,
- allow large request bodies for uploads, e.g. nginx `client_max_body_size 0;` (or a large limit).

## Private access with Tailscale

Keep Alcove off the public internet. Only devices on your tailnet can reach it, with a valid HTTPS
certificate from Tailscale.

1. Install Tailscale on the host and enable MagicDNS + HTTPS certificates in the admin console.
2. In `.env`, set `ALCOVE_DOMAIN=<machine>.<tailnet>.ts.net`.
3. Start only Alcove on localhost and let Tailscale serve it:

```sh
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d alcove
sudo tailscale serve --bg 8090
```

Open `https://<machine>.<tailnet>.ts.net` from any device in your tailnet (including the mobile app).

## Backup

Everything lives in the `alcove_data` volume: the SQLite database (`pb_data/data.db`) and files
(`pb_data/storage`, unless you use S3).

**Option A: built-in backups (recommended).** Admin UI → Settings → Backups: create a backup now or
schedule one (cron), keep N copies, and optionally upload them to S3. Backups are consistent zip archives
of `pb_data`. Copy them off the host regularly:

```sh
docker compose cp alcove:/data/pb_data/backups ./backups
```

**Option B: volume snapshot** (stop the server to get a consistent copy):

```sh
docker compose stop alcove
docker run --rm -v alcove_alcove_data:/data -v "$PWD":/backup alpine \
  tar czf /backup/alcove-$(date +%F).tar.gz -C /data .
docker compose start alcove
```

If you use S3 storage, back up the bucket separately (versioning or provider snapshots).
Keep at least one copy off-site and encrypted, e.g. with restic or borg.

## Restore

- **From a built-in backup:** admin UI → Settings → Backups → upload/restore. The server restarts with the restored data.
- **From a volume snapshot:**

```sh
docker compose down
docker volume rm alcove_alcove_data && docker volume create alcove_alcove_data
docker run --rm -v alcove_alcove_data:/data -v "$PWD":/backup alpine \
  sh -c 'tar xzf /backup/alcove-YYYY-MM-DD.tar.gz -C /data && chown -R 65532:65532 /data'
docker compose up -d
```

Restore into a test instance from time to time to check that your backups work.

## Updates

Every release is signed; Alcove refuses to install anything whose signature or checksum does not verify.

- **From the app:** administrators see a banner when a new version is out. The **System** page shows the
  release notes and, for native installs, an **Update** button: database backup, install, restart (about a
  minute).
- **From the command line (native):** `sudo alcove update` (`--check` to only look). It backs up the
  database, installs, restarts and checks that the new version answers; if not, it **rolls back
  automatically** (binary and database).
- **Docker:** `./update.sh` next to `docker-compose.yml` (database backup, `docker compose pull`, restart).
  Pin a version with `ALCOVE_VERSION=x.y.z` in `.env` if you prefer to update deliberately.

If something goes wrong after an update made from the app: `sudo alcove rollback` restores the previous
binary and the pre-update database backup. Database backups made before updates are kept in
`pb_data/alcove_backups` (last 5); `alcove backup --dir=<data>/pb_data` makes one on demand.

Read the release notes before major versions; breaking changes are announced in the
[CHANGELOG](../CHANGELOG.md).
