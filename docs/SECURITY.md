# Security

## Reporting a vulnerability

**Please do not open a public issue.** Report privately through GitHub:
**[Report a vulnerability](https://github.com/Paul-Carouge/Alcove/security/advisories/new)**
(Security tab → "Report a vulnerability").

Include affected version/commit, a description, reproduction steps or proof of concept, and impact.

What to expect:
- Acknowledgement within **3 working days**, initial assessment within **10 days**.
- A fix or mitigation as fast as severity requires. Coordinated disclosure, by default **90 days** after
  the report or when a fix is released, whichever comes first.
- Credit in the advisory and release notes if you want it.

Supported versions: before 1.0, only the latest release gets security fixes. After 1.0, the latest
minor release does, and the previous one does for 3 months.

Good-faith research is welcome: test only your own instance, don't access other people's data, and don't
degrade service for others.

## Threat model

**Assets:** user files, photos and documents (and their metadata: EXIF location, OCR text, faces),
account credentials and tokens, share links, server configuration and secrets (S3 keys, SMTP).

**Trust boundaries:** the internet ↔ Caddy (TLS) ↔ Alcove server ↔ SQLite and file storage; the server ↔
optional module containers; the client devices.

| Threat | Examples | Mitigations |
|---|---|---|
| Network attacker | Sniffing, MITM, downgrade | HTTPS only (Caddy auto-TLS, HSTS, HTTP→HTTPS redirect). Mobile refuses `http://` in release builds. Android cleartext disabled. iOS ATS on |
| Credential attacks | Brute force, credential stuffing | Rate limiting on auth (5/min/IP default), optional MFA, real client IP through the trusted proxy header only |
| Account takeover via token theft | XSS, stolen device, leaked logs | Strict CSP (no inline/3rd-party scripts), tokens in Keychain/Keystore on mobile, `allowBackup=false`, tokens invalidated on password change, short-lived file tokens |
| Broken access control | Reading another user's files, IDOR | PocketBase API rules on every collection (deny by default), owner checks in custom routes, rules reviewed in migrations, API tests per rule |
| Share-link abuse | Guessing, link leaks, indexing, password brute force | 256-bit tokens stored as SHA-256 (shown once), optional expiry (≤ 1 year) and bcrypt password, revocable, unlock tokens signed per share (1 h), folder links confined to their subtree, `noindex` + `no-referrer` on public pages, 10 password attempts/min/IP |
| Malicious uploads | Stored XSS through SVG/HTML, zip bombs, decompression and image parser bugs | Type sniffed from content at upload (client type ignored); downloads are attachments; inline display only for a passive-type allowlist, with a sandboxing CSP and `nosniff`; HTML/SVG never inline; 64 GiB size cap. *Planned:* thumbnailing in a separate process with resource limits |
| Injection | SQL, path traversal, header injection | Parameterized queries (dbx), storage keys generated server-side (never from file names), strict input validation |
| Server compromise impact | RCE in a dependency | Distroless non-root image, read-only root FS, all capabilities dropped, `no-new-privileges`, server not exposed directly (internal network) |
| Supply chain | Malicious dependency update | Lockfiles, Renovate with grouped reviewable PRs, CI on every change, PocketBase bumps need approval, GitHub Actions pinned by digest (Renovate) |
| Data loss | Disk failure, bad migration, ransomware on host | Documented backups and restores, reversible migrations, *planned:* automatic pre-migration backup |

**Out of scope (v1):**
- A malicious or compromised **server administrator**. Without end-to-end encryption, the admin can read
  all data. This is a deliberate trade-off ([ADR 0009](adr/0009-no-e2ee-in-v1.md)).
- Physical access to an unlocked client device.
- DoS beyond basic rate limiting. Put a CDN/WAF in front if you need that.

## Deployment best practices

- Use the provided `docker compose` stack. Don't publish port 8090 to the internet. Only Caddy should be reachable.
- Set `ALCOVE_TRUSTED_PROXY_HEADER` **only** when a proxy you control is the only way in. Otherwise
  clients can spoof their IP and bypass rate limits.
- Complete the first-run setup immediately after the first start: the setup link creates the administrator
  account and is valid for 30 minutes. If it expires, restart the container to get a new one, or run
  `docker compose exec alcove /alcove superuser upsert EMAIL PASSWORD`.
- Use a long unique admin password and enable MFA for the admin and users (admin UI → collection → Options).
- Configure SMTP (admin UI → Settings → Mail) so password resets and OTP emails work. Use a dedicated sender.
- Keep the host updated, enable automatic security updates, use a firewall (only 80/443 open, SSH by key).
- Prefer [Tailscale](SELF-HOSTING.md#private-access-with-tailscale) or another VPN if only you and your family use the instance.
- Back up regularly **and test restores**. Store one copy off-site, encrypted.
- Keep Alcove up to date. Watch the repository's releases/security advisories.
- `.env` contains secrets (S3 keys): `chmod 600 deploy/.env`. Never commit it.

## Security features checklist

| Feature | Status |
|---|---|
| HTTPS by default (Caddy) + HSTS | ✅ |
| Security headers (CSP, nosniff, frame-ancestors, referrer, permissions) | ✅ |
| Rate limiting (auth, creates, global) | ✅ enabled by migration |
| Hardened container (distroless, non-root, read-only, no caps) | ✅ |
| Strict env validation (fail at boot) | ✅ |
| Public sign-up disabled (admin-created accounts) | ✅ migration `1791680400_users_lockdown` |
| No account enumeration on password reset | ✅ |
| Share links (hashed tokens, expiry, password, revocation) | ✅ |
| MFA (password + email OTP) | ✅ available in PocketBase, to expose in our UI (phase 1) |
| TOTP authenticator apps | ⏳ phase 1 decision |
| Time-limited file URLs | ✅ PocketBase file tokens, used by drive (phase 1) |
| Tokens in Keystore/Keychain (mobile) | ✅ `SecureStore`, used from login (phase 1) |
| Audit log of sensitive actions | ⏳ planned |
| End-to-end encryption | ❌ not in v1 ([ADR 0009](adr/0009-no-e2ee-in-v1.md)) |
