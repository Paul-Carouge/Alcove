# 0006. Storage: local disk by default, S3 optional

- Status: Accepted (2026-10-11)

## Context

Most self-hosters store data on a local disk or NAS. Some prefer cheap object storage (Backblaze B2,
Wasabi, MinIO, Garage).

## Decision

Files are stored on **local disk by default** (`pb_data/storage` in a Docker volume). **S3-compatible
storage is optional**, configured with `ALCOVE_STORAGE=s3` and `ALCOVE_S3_*`, which are applied to
PocketBase's S3 settings at boot. Original files are never modified. Derivatives are stored separately.

## Consequences

- ✅ Zero-config default, and the database plus files can be backed up together.
- ✅ Object storage for large libraries without changing code.
- ⚠️ With S3, backups must cover the bucket separately, and latency is higher for thumbnails (cache needed later).
- ⚠️ Moving existing data between local and S3 needs a migration tool (later).
