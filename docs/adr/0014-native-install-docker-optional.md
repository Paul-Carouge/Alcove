# 0014. Native single-binary install first, Docker optional

- Status: Accepted (2026-10-12). Refines [0008](0008-docker-compose-caddy.md).

## Context

Self-hosting must be "one command" on almost any machine: a VPS, a Raspberry Pi, a NAS, a Mac mini or a
Windows PC. Requiring Docker excludes or burdens many of them. The server is already a single Go binary
with the web app embedded, and PocketBase can obtain Let's Encrypt certificates itself.

## Decision

- **Primary path:** a one-line installer (`install.sh`, `install.ps1`) downloads the right release binary
  and runs `alcove install`, which asks a few questions (public domain with automatic HTTPS, or local
  network / Tailscale), writes the configuration, and registers a system service (systemd on Linux,
  launchd on macOS, a Windows service on Windows).
- **Alternative:** the docker compose stack (Caddy + image) stays supported; the installer can set it up,
  with a small `alcove` wrapper for updates and logs.
- Release artifacts: binaries for linux (amd64, arm64, armv7), darwin (amd64, arm64) and windows (amd64).

## Consequences

- ✅ No Docker required; HTTPS works out of the box with a domain.
- ✅ The same `alcove` binary is server, installer and updater.
- ⚠️ Service management differs per OS; each path needs tests (unit generation, containerized install runs).
- ⚠️ Native installs bind ports 80/443 for automatic HTTPS (needs root or a capability on Linux).
