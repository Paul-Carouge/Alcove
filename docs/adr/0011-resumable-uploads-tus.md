# 0011. Resumable uploads with the tus protocol

- Status: Accepted (2026-10-11)

## Context

Drive and photo backup must handle large files (videos of several GB) over unreliable connections
(mobile, home uplinks). Plain multipart POSTs restart from zero on failure, and proxies may cap body size.

## Decision

Uploads use the **tus 1.0 resumable protocol** (core + creation, termination, checksum extensions),
served by the **tusd Go library (`github.com/tus/tusd/v2`) mounted inside the Alcove binary** at
`/api/v1/uploads/`. Partial uploads are stored on local disk under `pb_data/uploads` (also when the final
storage is S3). When an upload completes, a hook verifies ownership, quota and the checksum, then moves the
file into PocketBase storage as a `nodes` record and deletes the partial data. Stale partial uploads are
cleaned up by a cron job. Clients: `tus-js-client` (web), a Dart tus client or a thin implementation (mobile, phase 4),
and Rust (desktop, phase 6). The endpoint is documented in the OpenAPI spec like other custom routes.

## Consequences

- ✅ Pause and resume, progress, and chunking that works behind proxies with body limits. A well-specified protocol with mature clients.
- ✅ No custom protocol to design and secure ourselves.
- ⚠️ A new dependency (tusd). Its auth integrates through hooks (PocketBase token checked in the pre-create hook).
- ⚠️ Partial data needs local disk space and cleanup, even with S3 storage.
- ⚠️ Small files take more round-trips than a single POST. Batching tiny files may come later.
