# 0016. ffmpeg is bundled, not an optional container

- Status: Accepted (2026-10-12). Amends [0007](0007-optional-module-containers.md) for media processing.

## Context

Phase 2 (photos and videos) needs ffmpeg for video thumbnails/previews and formats Go cannot decode
(HEIC). ADR 0007 planned heavy processing in optional containers, but an extra container for every
photo library contradicts "hyper simple" self-hosting.

## Decision

ffmpeg is **included in the Docker image** and **installed by the native installer** through the system
package manager. Alcove detects it at runtime; without it, everything works except the formats that need
it (shown with a generic icon). OCR and face recognition, which need ML models and much more memory,
remain optional containers per ADR 0007.

## Consequences

- ✅ Photos and videos work out of the box.
- ⚠️ The Docker image moves from distroless/static to a small base with ffmpeg (larger, more packages to patch).
- ⚠️ ffmpeg runs on untrusted files: it runs as a separate process with time and memory limits.
