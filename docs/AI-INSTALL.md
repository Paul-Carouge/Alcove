# Install Alcove with an AI assistant

Want an AI assistant (Claude, ChatGPT, Gemini, a coding agent with shell access…) to install, update or
fix Alcove on your server for you? Copy the prompt below and paste it into your assistant. It contains
everything the assistant needs: the commands, where things live, how updates, backups and the app work,
and the mistakes to avoid. Replace the lines under **About my setup** first, or leave them and the
assistant will ask you.

The assistant should explain each command before running it. Never paste passwords or tokens into a
chat you do not trust; the assistant does not need your Alcove password.

````text
You are helping me self-host Alcove, an open-source personal cloud (files, photos and videos, documents
with OCR, notes, calendar), made by Paul Carouge. Source and releases:
https://github.com/Paul-Carouge/Alcove. It is a single Go binary (built on PocketBase) that embeds the web
app; the Android app connects to it. Alcove is pre-1.0: keep backups.

About my setup (ask me about anything left unfilled before running commands):
- Machine and OS: <e.g. Ubuntu 24.04 VPS, Raspberry Pi 4 with Raspberry Pi OS, a Mac mini, Windows 11>
- How I want to reach it: <only at home / from anywhere with my domain cloud.example.com / behind my existing nginx, Traefik or Caddy>
- What I want you to do: <install / update / back up / check that everything works / fix a problem>

How to work with me:
- Explain what each command does before running it, and ask before anything that deletes data, opens
  firewall ports or changes DNS.
- Prefer the native installer below. Use Docker only if I ask for it or Docker is clearly my setup.
- After each step, check the result (alcove status, curl /health) instead of assuming it worked.
- Never invent options: the commands and flags listed here are the real ones. If unsure, run
  `alcove --help` or `alcove <command> --help`.

== Requirements ==
- Linux x86-64, ARM64 or ARMv7 (Raspberry Pi 3+) with systemd or OpenRC; macOS (Intel or Apple Silicon);
  Windows 10/11 x86-64. 1 GB RAM minimum. Disk: my data plus about 10% for thumbnails and previews.
- The machine must reach github.com (downloads and updates). On minimal Linux systems install
  certificates first: `sudo apt install ca-certificates` (or the distribution's equivalent).
- Public HTTPS mode only: a domain whose DNS A/AAAA record points to this machine, and ports 80 and 443
  reachable from the internet (router port forwarding at home, cloud firewall/security group on a VPS).

== Choose the mode ==
| Situation | --mode | Address users open |
| Home network only (plus Tailscale when away) | local | http://<machine LAN IP>:8090 |
| Reachable from anywhere with a domain, automatic HTTPS (Let's Encrypt) | public | https://<domain> |
| An existing reverse proxy terminates TLS | proxy | the proxy's address (Alcove listens on 127.0.0.1:8090) |

== Install (native, recommended) ==
Linux and macOS, interactive (asks the mode and a few questions):
  curl -fsSL https://github.com/Paul-Carouge/Alcove/releases/latest/download/install.sh | sh
The script downloads the right binary, verifies its checksum and runs `alcove install` with sudo.

Non-interactive (for you, the assistant, or cloud-init). Real flags of `alcove install`:
  --mode public|local|proxy   --domain <name> (public mode)   --port <n> (local/proxy, default 8090)
  --yes / -y (accept defaults, no questions)   --no-ffmpeg   --no-ocr   --no-start
Examples:
  curl -fsSL https://github.com/Paul-Carouge/Alcove/releases/latest/download/install.sh | sh -s -- --mode local --yes
  curl -fsSL https://github.com/Paul-Carouge/Alcove/releases/latest/download/install.sh | sh -s -- --mode public --domain cloud.example.com --yes

Windows (PowerShell as administrator):
  irm https://github.com/Paul-Carouge/Alcove/releases/latest/download/install.ps1 | iex

What the installer does: creates a dedicated system user (Linux), installs the service (systemd, OpenRC,
launchd or a Windows startup task), offers Alcove's own recent ffmpeg (needed for video and HEIC photo
thumbnails; HEIC needs ffmpeg 7.1+, older distributions ship older ones) and OCR tools (Tesseract +
poppler, French and English) on Linux, or Homebrew/winget on macOS/Windows, starts Alcove and prints the
setup link.

== First-run setup ==
The installer prints a link like http://<address>:8090/setup?token=… (or https://<domain>/setup?token=…).
I open it in a browser to create the administrator account (used for both the app and the admin console),
optionally configure email (SMTP), and check storage. If the link is lost, the token is the
ALCOVE_SETUP_TOKEN line of the config file (paths below), e.g.
  sudo grep ALCOVE_SETUP_TOKEN /etc/alcove/alcove.env
The token only works until setup is completed. Use the machine's LAN IP or domain in the link, never
localhost, when I open it from another device.

== Where things live ==
| | Linux | macOS (sudo) | macOS (user) | Windows |
| Binary | /var/lib/alcove/bin/alcove (+ /usr/local/bin/alcove) | /usr/local/lib/alcove/alcove | ~/Library/Application Support/Alcove/bin | %ProgramFiles%\Alcove |
| Data | /var/lib/alcove | /usr/local/var/alcove | ~/Library/Application Support/Alcove | %ProgramData%\Alcove |
| Config | /etc/alcove/alcove.env | /usr/local/etc/alcove/alcove.env | same folder as data | %ProgramData%\Alcove\alcove.env |
The database and files are in <data>/pb_data (data.db and storage/). ALCOVE_SECRET_KEY (in the config, or
pb_data/secret.key) encrypts two-factor secrets: it must be kept with backups.

== Everyday commands ==
  alcove status              service state, address, version, ffmpeg, OCR, pending update
  sudo alcove update         update to the latest release (--check only looks, --yes no questions)
  sudo alcove rollback       go back to the previous binary and the pre-update database backup
  sudo alcove uninstall      remove the service, keep data (--purge also deletes data and config)
  alcove backup --dir=<data>/pb_data   make a database backup now
  journalctl -u alcove       server log on Linux with systemd
  curl -fsS http://127.0.0.1:8090/health   health check (or https://<domain>/health); returns version and modules

== Updates ==
- Every release is signed; Alcove refuses anything whose signature or checksum does not verify.
- Command line: `sudo alcove update`. It backs up the database, installs, restarts, checks that the new
  version answers, and rolls back automatically if it does not.
- From the web app: administrators see a banner when a release is out; the System page shows release
  notes and an Update button (native installs).
- Docker: run `./update.sh` next to docker-compose.yml (database backup, pull, restart, health check).
- Pre-update database backups are kept in <data>/pb_data/alcove_backups (last 5).
- Read the CHANGELOG before updating across many versions:
  https://github.com/Paul-Carouge/Alcove/blob/main/CHANGELOG.md

== Backups and restore ==
- Built-in (recommended): admin console at <address>/_/ → Settings → Backups: back up now or on a schedule,
  keep N copies, optionally upload to S3. Copy the archives off the machine regularly.
- Manual: stop the service, copy the whole data directory (pb_data), start it again.
- Restore: admin console → Settings → Backups → upload/restore (the server restarts).
- Keep at least one copy off-site and encrypted (restic, borg…), and test a restore from time to time.

== Docker (alternative) ==
  git clone https://github.com/Paul-Carouge/Alcove.git && cd Alcove/deploy
  cp ../.env.example .env && chmod 600 .env
  # edit .env: ALCOVE_DOMAIN=cloud.example.com and ALCOVE_ACME_EMAIL=me@example.com
  docker compose up -d
  docker compose logs alcove        # prints the setup link
Behind an existing reverse proxy, run only Alcove on 127.0.0.1:8090:
  docker compose -f docker-compose.yml -f docker-compose.local.yml up -d alcove
Settings are environment variables in deploy/.env (documented in .env.example): ALCOVE_DOMAIN,
ALCOVE_ACME_EMAIL, ALCOVE_STORAGE (local or s3) and ALCOVE_S3_*, ALCOVE_UPDATE_CHECK, ALCOVE_SETUP_TOKEN
(16+ chars, presets the setup link), ALCOVE_SECRET_KEY (32+ chars), ALCOVE_VERSION (image tag). Invalid
values stop the server at boot with an explicit message in the logs.

== Reverse proxy requirements (proxy mode) ==
- Terminate TLS, redirect HTTP to HTTPS, add HSTS.
- Forward to http://127.0.0.1:8090 with X-Forwarded-For and X-Forwarded-Proto.
- Disable response buffering (realtime updates use /api/realtime), e.g. nginx `proxy_buffering off;`.
- Allow large uploads, e.g. nginx `client_max_body_size 0;`.

== Private access with Tailscale ==
Install in local mode, then from other devices on the tailnet open http://<tailscale IP or name>:8090, or
serve it over HTTPS with `sudo tailscale serve --bg 8090` and open https://<machine>.<tailnet>.ts.net.

== The Android app ==
- Download: Account → "Alcove on your phone" in the web app (the server serves the APK of its own version),
  or from the latest GitHub release: alcove-android-arm64-v8a.apk for most recent phones,
  alcove-android.apk (universal) if unsure.
- In the app, enter the server address. HTTPS always works; plain http is accepted only for home-network
  addresses (192.168.x.x, 10.x.x.x, .local, Tailscale). An address typed without http:// is tried with
  HTTPS first, then http for home-network addresses.
- The app updates itself from the server after the server is updated (Android asks once to allow installs
  from Alcove).

== After installing, check ==
1. `alcove status` shows the service running and the expected address.
2. `curl -fsS <address>/health` answers with "status":"ok".
3. The setup link opens from another device (firewall: e.g. `sudo ufw allow 8090/tcp` in local mode, or
   80 and 443 in public mode).
4. Suggest next steps: schedule backups (Settings → Backups), turn on two-factor sign-in (account menu →
   Security), install the Android app.

== Troubleshooting ==
- Setup link does not open from the phone: use the LAN IP, same network, port 8090 open in the firewall.
- "cannot reach the release server": the machine cannot reach github.com, or certificates are missing.
- HTTPS fails in public mode: DNS must point to the machine and ports 80/443 must reach it; check
  `alcove status`.
- Photos or videos without thumbnails: ffmpeg missing or too old; `alcove status` shows it, and
  `sudo alcove update` installs Alcove's own copy on Linux.
- Scans not searchable: OCR tools are optional; see Documents and OCR on the System page.
- Anything else: `alcove status`, then the log (`journalctl -u alcove -n 200` on Linux).

Full guide: https://github.com/Paul-Carouge/Alcove/blob/main/docs/SELF-HOSTING.md
````
