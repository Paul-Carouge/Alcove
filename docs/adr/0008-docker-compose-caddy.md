# 0008. Deployment: docker compose with Caddy

- Status: Accepted (2026-10-11)

## Context

Installation must be a few commands, with HTTPS that works without manual certificate handling.

## Decision

The reference deployment is **`docker compose up`** with two services: the Alcove server (distroless,
non-root, read-only image) and **Caddy** for automatic HTTPS (Let's Encrypt), HTTP/2-3, HSTS and
compression. The server is reachable only from Caddy on an internal network. First-run setup uses
PocketBase's one-time installer link, printed with the public URL. A dedicated web wizard comes in phase 1.
An override file supports existing reverse proxies and Tailscale.

## Consequences

- ✅ Three commands to a working HTTPS instance. Certificates renew automatically.
- ✅ The same image runs everywhere (multi-arch builds planned).
- ⚠️ Requires ports 80/443 and a domain for public access. Tailscale is documented for private setups.
- ⚠️ Bare-metal installs (systemd + binary) are possible but not the primary documented path.
