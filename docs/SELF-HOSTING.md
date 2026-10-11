# Self-hosting

> Alcove is in early development. These instructions work, but there are no features worth hosting yet.

## Requirements

- A 64-bit Linux host (x86_64 or arm64; a Raspberry Pi 4/5 works), 1 GB RAM minimum, 2 GB+ once photos arrive.
  Disk: your data plus about 10% for thumbnails.
- Docker Engine 24+ with the Compose plugin (`docker compose version`).
- For public HTTPS: a domain or subdomain whose DNS `A`/`AAAA` record points to the host, with ports
  **80 and 443** reachable from the internet (Let's Encrypt uses them).
  For private use only, see [Tailscale](#private-access-with-tailscale) instead.

## Install

```sh
git clone https://github.com/Paul-Carouge/Alcove.git && cd Alcove/deploy
cp ../.env.example .env && chmod 600 .env
nano .env                     # ALCOVE_DOMAIN=cloud.example.com, ALCOVE_ACME_EMAIL=you@example.com
docker compose up -d
```

The first start builds the image (a few minutes). Once images are published, it will pull
`ghcr.io/paul-carouge/alcove` instead.

**First-run setup:** run `docker compose logs alcove` and open the printed link
(`https://<domain>/_/#/pbinstall/…`, valid 30 minutes) to create the administrator account.
Alternative: `docker compose exec alcove /alcove superuser upsert you@example.com 'a-long-password'`.

Check it is up: `curl https://<domain>/health`.

**Recommended next steps** in the admin UI (`https://<domain>/_/`): Settings → Mail (SMTP), Settings →
Backups (schedule), users collection → enable MFA.

### Configuration

All settings are environment variables in `deploy/.env` (documented in [`.env.example`](../.env.example)):

| Variable | Default | Purpose |
|---|---|---|
| `ALCOVE_DOMAIN` | required | Public hostname. Used by Caddy and in links |
| `ALCOVE_ACME_EMAIL` | required | Let's Encrypt account email |
| `ALCOVE_STORAGE` | `local` | `local` or `s3` |
| `ALCOVE_S3_*` | | Endpoint, region, bucket, keys, path style (when `s3`) |
| `ALCOVE_MODULES` | empty | Optional modules (`ocr`, `faces`). Not implemented yet |
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

1. Read the release notes (breaking changes, migration notes).
2. **Back up** (see above).
3. Update:

```sh
cd Alcove && git pull                 # until images are published: rebuilds from source
cd deploy && docker compose up -d --build
# once images are published:  docker compose pull && docker compose up -d
```

Database migrations run automatically at start. If something goes wrong, restore the backup and run the
previous version (`ALCOVE_VERSION=<previous>`). Released migrations are reversible, but restoring the
backup is the safest way back.

Pin a version in production with `ALCOVE_VERSION=x.y.z` and update deliberately.
