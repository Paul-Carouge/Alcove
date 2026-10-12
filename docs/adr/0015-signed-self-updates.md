# 0015. Self-updates from signed releases (CLI, web and mobile)

- Status: Accepted (2026-10-12)

## Context

Updating must be as easy as installing: one command, or one button for the administrator in the web
or mobile app. A self-updating server is also an attack vector: whoever controls the downloaded binary
controls the server.

## Decision

- Each release publishes `SHA256SUMS` signed with an **Ed25519 key** held only by the maintainer (GitHub
  secret). The public key is compiled into the binary. An update is applied only if the signature and
  the checksum verify.
- `alcove update` (and the admin "Update now" button, native installs) checks the latest release, verifies
  it, **backs up the data first**, swaps the binary atomically and restarts the service. Docker installs
  get the equivalent through `alcove update` on the host (backup, pull, restart); the web UI shows that
  command instead of a button.
- The server checks for new releases once a day (can be disabled with `ALCOVE_UPDATE_CHECK=false`) and
  shows administrators the version and changelog. Users get a new `role` field (`user` or `admin`).

## Consequences

- ✅ One command or one click to update; a backup always precedes it.
- ✅ A compromised download location cannot push a binary without the signing key.
- ⚠️ Losing the signing key means rotating it in a release that users install manually once.
- ⚠️ The daily check contacts GitHub (documented; opt-out).
