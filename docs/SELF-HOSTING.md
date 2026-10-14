# Self-hosting

> Alcove is in early development. Keep backups and expect breaking changes before 1.0.

## In three steps

1. **Install** on the machine that will keep your files (a PC at home, a Raspberry Pi, a cloud server):
   `curl -fsSL https://github.com/Paul-Carouge/Alcove/releases/latest/download/install.sh | sh`
2. **Open the link it prints** (`http://<address>:8090/setup?token=…`, or `https://<your domain>/…`)
   from any computer or phone on the same network, and create your account.
3. **Install the app** on your phone from Account → Alcove on your phone, and enter the same address.

Which mode to choose when the installer asks?

| You want… | Choose | Address |
|---|---|---|
| Use it only at home (and through Tailscale when away) | **Local network** | `http://192.168.x.y:8090` |
| Reach it from anywhere with your own domain name | **Internet with a domain** | `https://cloud.example.com` |
| You already run nginx, Traefik or Caddy | **Behind your reverse proxy** | yours |

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
Windows startup task), offers a recent ffmpeg, starts Alcove and prints the setup link.

**ffmpeg** is needed for video and HEIC thumbnails (the Docker image includes it). HEIC photos from
phones need **ffmpeg 7.1 or newer**, and Debian 12 or Ubuntu 24.04 ship older versions, so on Linux the
installer offers Alcove's own ffmpeg (about 45 MB, kept in `/var/lib/alcove/bin/ffmpeg`, the system is not
changed; [ADR 0017](adr/0017-ffmpeg-bundle-for-native-linux.md)). Updates keep it current. On macOS and
Windows it uses Homebrew or winget. Without ffmpeg, JPEG, PNG and WebP photos still work; videos and HEIC
files show without a thumbnail until it is installed (they are retried daily).

**OCR** (searching the text of scans and screenshots) uses Tesseract and poppler. On Linux the installer
offers Alcove's own copy (about 25 MB in `<bin dir>/ocr`, French and English;
[ADR 0025](adr/0025-documents-and-ocr.md)); the Docker image includes them; on macOS and Windows the
installer offers Homebrew or winget. Already installed? An administrator can install them from the
**System** page (native Linux), or run the command shown there. Without them, PDFs that contain text and
text files are still searchable.

Installed before v0.10.2? Run `sudo alcove update` once: it adds the recent ffmpeg even when Alcove is
up to date. `alcove status` shows which ffmpeg is used.

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

**Users and quotas:** in the app, account menu → **Users** (administrators). Create an account (a
password is generated for you to hand over), set a storage quota in GB (trash included; empty means
unlimited), make someone an administrator, reset a password or delete an account. Users change their
name and password in **Account**, see their usage in the sidebar, and cannot change their own quota or
role.

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

**Mobile app.** Android users download the app from the web app (Account → Alcove on your phone; your
server serves the APK of its own version) and enter your server's address. HTTPS addresses always work;
plain `http://` is accepted only for private-network addresses (home network, `.local`, Tailscale), with a
warning. The iPhone app comes later.

The app **updates itself from your server** ([ADR 0024](adr/0024-in-app-updates.md)): after you update
Alcove, phones show a badge on the Account tab and an **Update now** button at their next launch. The
server downloads the matching APK from the GitHub release once (kept in `pb_data/app`), and Android only
installs it if it carries the same signature as the installed app. The first time, Android asks to allow
installing apps from Alcove.

**Documents.** Alcove reads the text of PDFs and text files and, with OCR, of scanned PDFs and
screenshots (images without camera information), so they can be searched from the **Documents** page or
the search box. Everything happens on your server, one document at a time. Administrators see the tools
and progress on the System page, and can turn OCR off there. A scan can also be turned into a
**searchable PDF** (its text selectable in any PDF reader), saved next to it as `<name> (OCR).pdf`.

**Map tiles.** The photo map uses a world map built into Alcove: no request leaves your server. An
administrator can enable detailed OpenStreetMap tiles on the System page; browsers then load them from
tile.openstreetmap.org (which sees the area viewed). For many users, prefer your own tile server (planned).

Read the release notes before major versions; breaking changes are announced in the
[CHANGELOG](../CHANGELOG.md).

## Troubleshooting

- **The setup link does not open from my phone.** Use the address the installer printed (an IP such as
  `192.168.1.20`), not `localhost`. Phone and server must be on the same network, and port 8090 open in
  the server's firewall (`sudo ufw allow 8090` on Ubuntu).
- **"cannot reach the release server".** The installer or `alcove update` needs to reach GitHub. On minimal
  systems, install the certificate store first (`sudo apt install ca-certificates`).
- **HTTPS does not work with my domain.** The domain's DNS must point to this machine, and ports 80 and 443
  must reach it (router port forwarding at home). Check with `alcove status`.
- **Photos have no thumbnail.** Videos and HEIC need ffmpeg: `alcove status` shows which one is used;
  `sudo alcove update` installs Alcove's own copy on Linux.
- **Scans are not searchable.** The OCR tools are optional: see Documents and OCR on the System page.
- **Something else.** `alcove status` shows the service, its address, ffmpeg, OCR and pending updates;
  `journalctl -u alcove` (Linux) shows the server's log.
