# 0017. Native Linux installs get Alcove's own ffmpeg

- Status: Accepted (2026-10-12). Amends [0016](0016-bundled-ffmpeg.md) for native Linux installs.

## Context

ADR 0016 installs ffmpeg with the system package manager on native installs. Debian 12 (5.1) and Ubuntu
24.04 (6.1), the most common server systems, ship versions that cannot decode the HEIC photos phones
produce (tiled HEIF, supported since ffmpeg 7.1). Users would see thumbnails missing for most of their
iPhone pictures, with no obvious fix.

## Decision

Each release publishes a **self-contained ffmpeg per Linux architecture** (`ffmpeg_linux_{amd64,arm64,armv7}.tar.gz`),
built by `scripts/ffmpeg-bundle.sh` from **unmodified Alpine packages** (the same ffmpeg as the Docker image)
with their shared libraries and the musl loader, started through small `sh` wrappers. It runs on any Linux
distribution regardless of its C library.

- The bundles are listed in the signed `SHA256SUMS` and verified like the binary.
- `alcove install` installs the bundle next to the binary (`<bin dir>/ffmpeg/`) when the system ffmpeg is
  missing or older than 7.1, after asking. `alcove update` and the in-app update keep it current;
  `sudo alcove update` also installs it on an up-to-date server. The system is never modified.
- At startup the server puts the bundle first on its `PATH`. macOS (Homebrew) and Windows (winget) keep
  using the package manager, whose versions are current.

## Consequences

- ✅ HEIC and videos work on every supported Linux system, with the same ffmpeg everywhere.
- ✅ ffmpeg security fixes reach native installs with Alcove updates.
- ⚠️ About 45 MB downloaded once, ~90 MB on disk; releases carry three more assets.
- ⚠️ We redistribute GPL software: each bundle has a README naming its packages and sources, and the
  maintainers provide the corresponding source on request (GPL-2.0 §3b).
- ⚠️ Updates made by a version older than 0.10.2 do not install the bundle; `sudo alcove update` does.
