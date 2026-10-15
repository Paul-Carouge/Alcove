# 0027. Notes are stored in the database, not as Markdown files

- Status: Accepted (2026-10-15).

## Context

Phase 5 adds Markdown notes with realtime sync. Two designs were possible: each note is a `.md` file in
the drive (a `nodes` record with a blob), or each note is a row of its own PocketBase collection. Files
would make notes visible in Files and in any future WebDAV or desktop sync, but every keystroke-level
save would rewrite a blob, bump the drive's quota and history, and searching, tagging, pinning and
sharing would need code on top of the file layer. The owner chose the database.

## Decision

- A `notes` collection (migration `1791738000_notes`): `owner`, `title` (up to 200 characters), `body`
  (Markdown text, up to 1 MiB), `pinned`, `tags` (the existing `tags` collection, up to 20, checked to
  belong to the owner like on files), `trashed_at`, `created`, `updated`.
- **Rules**: every read and write is restricted to the owner; the owner cannot be changed. No custom
  endpoint: clients use PocketBase's record API, and realtime comes from its SSE subscriptions, filtered
  by the same rules.
- **Trash**: like files, deleting sets `trashed_at`; notes trashed for more than 30 days are deleted for
  good by a daily job (`internal/notes`). Restoring clears the date.
- **Search**: the notes list filters on title and body (`~`, a case-insensitive substring match), and the
  web's global search shows matching notes above files. Notes are not added to the documents FTS index
  for now; a dedicated index can come when lists get large.
- `/health` advertises the `notes` module.
- Clients render a small, safe Markdown subset (headings, lists, checkboxes, bold, italic, code,
  quotes) from escaped text; no raw HTML, no rich-text editor dependency.

## Consequences

- ✅ Realtime, search, tags, pinning and later sharing between accounts are ordinary collection
  features: no file locking, no blob rewrites, no quota churn on every autosave.
- ✅ Backups already include notes (they are in `data.db`).
- ⚠️ Notes do not appear in Files, WebDAV or the desktop sync. A Markdown export (one `.md` per note,
  or a ZIP) stays possible and simple, since the body is plain Markdown.
- ⚠️ Notes do not count toward the storage quota (text only, 1 MiB at most each).
- ⚠️ Last write wins: two devices editing the same note at the same second keep the later save. Clients
  apply remote changes only when the local editor has no pending edits.
