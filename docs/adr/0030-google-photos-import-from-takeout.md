# 0030. Google Photos import from Google Takeout

- Status: Accepted (2026-10-16). Builds on [0011](0011-resumable-uploads-tus.md),
  [0018](0018-albums-and-sharing-between-accounts.md) and [0022](0022-mobile-photo-backup.md).

## Context

Most people who install Alcove for their photos come from Google Photos. Google's Photos Library API no longer
lets an app read a whole library (since 2025 it only sees what the app uploaded itself), so the only complete
export is **Google Takeout**: `.zip` archives of 2 to 50 GB each, with every photo next to a JSON "sidecar"
holding what Google knows (date taken, place, description, favorite, archived, trashed) and album folders with
a `metadata.json`. Takeout has well-known quirks: a photo's JSON may be in another archive of the same export;
sidecars are named `photo.jpg.json` or `photo.jpg.supplemental-metadata.json`, cut at 51 characters
(`.supplemental-metad.json`, `.suppl.json`, or the name itself); duplicates are `photo(1).jpg` ↔
`photo.jpg(1).json`; edited copies (`-edited`, `-modifié`…) have no JSON; Live Photos are an image plus a
video; a photo in an album is in the archive twice (library folder and album folder).

## Decision

**Input.** Takeout `.zip` archives, read with Go's `archive/zip` directly, entry by entry, without extracting
them. Two ways to provide them:

- **Upload from the web app**, through the existing tus endpoint with `purpose=import` metadata, so 50 GB
  archives survive bad connections. When complete they are moved to `pb_data/import-uploads/<user>/<id>.zip`
  (with their original name beside them): temporary import files, not drive files. Per account, at most 200
  archives (finished and in progress) and, in bytes, what is left of the quota, or without quota the
  server-wide `imports.max_upload_bytes` app setting (500 GB by default, changed in the admin console);
  beyond, 413 `ERR_IMPORT_LIMIT`. Every import upload and chunk, and every import job, must leave 5% of the
  volume (at least 5 GB) free, counting what other partial uploads still announce; otherwise 507
  `ERR_DISK_FULL`. Regular uploads (drive, phone backup) only keep a safety floor for SQLite, 1% (at least
  512 MB), so a small SD card keeps taking phone backups; the apps show it as "not enough space" and the
  phone retries on its next run. Archives are deleted after a successful import only: after a failure or a
  cancel they stay, listed in the web app, so a new job can use them again (or the user deletes them); an
  account's unused archives go once nothing was uploaded for a day (someone sending 10 × 50 GB keeps the
  first ones while sending the last).
- **Server folder** (administrators only): archives or an already extracted folder copied into
  `pb_data/import/`, picked in the web app, imported into any account. Every access goes through `os.Root`
  (no `..`, no symbolic link out of the folder; links are not even listed). These files are never deleted.

**Matching** (`internal/takeout`, pure and table-tested): entries are grouped by folder path across all
archives; each photo or video finds its sidecar by trying its full name plus every cut of
`.supplemental-metadata`, then the `(n)` counter moved after the stem (full, then cut), then cuts of the name
itself when it is long enough to have been truncated (40+ characters), then the original's name for an
edited copy. A cut stem belongs to one file only (edited copies and Live Photo videos share their
original's), so a long `(1)` copy never takes its original's JSON. A Live
Photo video without JSON takes the image's. Files without JSON are imported with what the file itself says.

**Metadata goes into the database, never into the files** (rule 7). The file is saved outside any
transaction (copying a video into storage must not hold SQLite's only write connection), with the size and
SHA-256 the importer computed while extracting it, so it is read once. Google's values wait in memory,
keyed by owner and SHA-256, and the media hook creates the `media` record with them (hidden
`import_taken_at`, `import_has_location`, `import_lat`, `import_lon`, plus `description` and `favorite`), so
the worker never sees the file without them. The media worker merges them on every
processing (so retries and backfills never lose them):

- **Date:** the file's EXIF (or video) date wins when it is plausible; Google's `photoTakenTime` (UTC) is used
  when the file has none, or when its date is before 1971, more than two days in the future, or exactly
  midnight on 1 January (a reset camera clock) while Google's is more than a day away. Small differences
  (EXIF has no time zone) keep EXIF, like for every other photo of the library.
- **Place:** EXIF GPS when present, else Google's `geoData`, else `geoDataExif`; `0,0` means "none".
- **Trashed** items are skipped; **archived** ones are imported like the others (Alcove has no archive).

**Albums.** "Photos from YYYY" folders (in the languages Takeout uses) are the library; a folder with album
metadata is an album, recreated for the user (an existing album with the same name is reused, so re-running
completes it). Folders without metadata ("Archive", "Trash"…) are library. Library items are imported first,
so an album's copy of a photo is recognized as the same file and only added to the album.

**Destination.** Files go to a root folder **"Google Photos"**, one sub-folder per year: the "Photos from
YYYY" folder's year, else the year taken in the server's time zone; undated album-only photos stay at the
root. Phone backups use one flat root
folder ("Phone backup", ADR 0022), which suits a steady trickle; an import brings tens of thousands of files
at once, and per-year folders keep the drive browsable and mirror Takeout's own layout. The name is Google's
product name, the same in every language.

**Deduplication** by SHA-256 against all the user's files, trash included (like `backup/known`): re-running an
import, or importing photos the phone already backed up, adds nothing; such a photo is still added to its
albums, and gets Google's favorite, description, date and place when it has none (what the user set is never
overwritten; the worker processes it again when the merge can change its date or place). This also recovers
Google's values for a photo saved just before a crash, while they only lived in memory. Within a job, a lock per hash stops two copies from both being imported. A phone backup of the
same photo can land between the check and the save (`nodes` has no unique owner + hash): after saving, the
importer looks again and deletes its own copy when an older one exists. Two writers finishing within the same
instant can still both keep theirs; the duplicates page shows it.

**Jobs** are records of a new `imports` collection (owner, starting administrator, source, files, status
`queued → scanning → running → done | failed | cancelled`, counters, the first 1000 failures, hidden resume
state), readable by their owner and the administrator who started them, written only by the server. One job
runs at a time per server (others wait in `queued`); two workers import entries in parallel and the importer
waits while the media worker has more than 1000 pending items, so a Raspberry Pi stays usable and the media
queue never overflows. Progress is saved at most every 500 ms as "every item before N, plus these few"; a
restart puts interrupted jobs back in the queue and they resume where they stopped (an item finished just
before a crash is found again as a duplicate). Clients follow a job through PocketBase realtime. A job stops
with a clear error when the quota is full (`quota_exceeded`, checked before each file is decompressed), the
disk is too small for the remaining photos (`disk_full`, checked before importing: each content once, trashed
items not at all, the disk's floor kept), archives are unreadable or unsafe (`unsafe_archive`). A clean
shutdown (update, restart) puts a running job back in the queue; a job found still running at startup was
stopped by a crash, and after three such crashes in a row without progress it fails as `interrupted` instead
of crashing the server again. Administrators can cancel any job.

**API** (OpenAPI): `POST /api/v1/imports/google` (uploads, or server files and a target user for
administrators; one unfinished job per account), `GET /api/v1/imports/google/server-files` (administrators),
`POST /api/v1/imports/{id}/cancel`; jobs are read through the record API. Rate limit: 30/min on
`/api/v1/imports/`.

**Hostile archives.** Entry names are never used as paths on disk (each entry streams into a temp file Alcove
names); names with `..`, absolute paths, backslashes, control characters (C0 and C1), invalid UTF-8 or more
than 1024 bytes are ignored, and invisible format characters (bidi overrides, zero-width) become `_` in
names (and are dropped from descriptions). `archive/zip` allocates every central directory header it reads, from wherever
crafted end records make it start (shifted offsets, ignored ZIP64 locators): Alcove therefore gives it a
reader that refuses to serve more than 48 MB (plus a little for the end records) while it parses, which
bounds the headers whatever the archive claims, then lifts the limit for the data. After parsing, at most
200 000 entries per archive and 1 000 000 per job across archives (a real 50 GB archive holds a few tens of
thousands).
Entries must not overlap nor point past the file (one compressed stream read thousands of times); a job never
decompresses more than 100 times the size of its archives; an entry larger than 16 MiB compressed more than
100:1 is refused; entries are read up to their declared size and must match it; each is capped at the drive's
64 GiB (larger declared sizes are clamped, so sums cannot overflow); JSON files at 1 MiB. Only content sniffed
as a photo or video becomes a file (camera RAW formats the sniffer does not know excepted). In the server
folder, hard links are skipped (`os.Root` cannot tell where they point; not checked on Windows). Reads stop
as soon as a job is cancelled. Failure paths are cut at 300 characters and the list at 512 KB, and a job's
final status is always written. Temp files live in `pb_data/import-work` and are removed after each entry, at
the end of each job and at boot.

**Not done:** Live Photo pairs are imported as two items next to each other (the media model has no link
between them yet); edited copies are imported next to their original (no stacking either); album
descriptions, comments and shared-album contributors are not imported; nested zips in a server folder are not
opened; archives are all opened at the start of a job (bounded by the limits above, not lazily); the mobile
app shows nothing (50 GB archives are a desktop or server affair).

## Consequences

- ✅ A whole Google Photos library, with dates, places, descriptions, favorites and albums, without any
  original being modified, and without duplicates when the phone was already backed up.
- ✅ Resumable at every level: tus for uploads, saved progress for the job, deduplication for re-runs.
- ⚠️ Uploaded archives need as much free disk as their size until the import succeeds, plus the photos
  themselves. A failed or cancelled import keeps them until reused, deleted, or a day without uploads.
- ⚠️ Takeout's naming quirks are reverse-engineered; a future change at Google may need a new matching rule.
- ⚠️ Live Photos and edited copies show as separate items until the media model learns to group them.
