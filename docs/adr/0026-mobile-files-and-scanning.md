# 0026. Mobile: sending files with the system picker, scanning with ML Kit

- Status: Accepted (2026-10-13).

## Context

The Android app could browse files and back up photos, but not add a document, a folder or a scan. The
user asked for a complete Files tab and chose the dependencies.

## Decision

- **file_picker** opens the system file picker (Storage Access Framework on Android: no storage
  permission). Files without a local path are copied to the app's cache before sending.
- **google_mlkit_document_scanner** scans pages with edge detection and cropping into one PDF, named
  `Scan YYYY-MM-DD HH.mm.pdf`, which the server then reads by OCR (ADR 0025). It runs on the phone through
  Google Play services (its module is downloaded by Play services on first use); nothing is sent to Google.
  Phones without Play services get a clear message; they can still send PDFs made by another app.
- Uploads reuse the backup's tus client (ADR 0011), one file at a time, with progress in a banner at the
  bottom of Files. Folder creation, rename, move (folder picker that cannot enter the moved folder) and
  trash (with Undo) use the `nodes` collection API, like the web app.

## Consequences

- ✅ Everything the web drive does day to day can be done from the phone.
- ⚠️ Scanning depends on Google Play services; an F-Droid build would need another scanner.
- ⚠️ Uploads stop if the app is closed (backups keep running in the background as before).
