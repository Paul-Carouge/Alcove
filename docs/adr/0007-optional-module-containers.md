# 0007. OCR and face recognition as optional containers

- Status: Accepted (2026-10-11), implementation in phases 2–3

## Context

OCR and face recognition need heavy native dependencies (Tesseract, ML models, sometimes GPUs) and
lots of RAM. Bundling them would bloat the binary and break "runs on a Pi".

## Decision

They run as **optional, separate containers** enabled by the admin (`ALCOVE_MODULES=ocr,faces` plus a
compose profile). The server sends them jobs over the internal network and stores the results. The core
works fully without them, and `/health.modules` advertises what is active so clients can hide unavailable features.

## Consequences

- ✅ Small, portable core. Heavy features are opt-in, replaceable and independently updatable.
- ✅ Process isolation for risky parsers.
- ⚠️ A job queue and internal API between server and workers must be designed (phase 2/3).
- ⚠️ More moving parts for users who enable them.
