# 0018. Albums, and sharing them between accounts

- Status: Accepted (2026-10-12). Public album links follow in v0.12 on the same model.

## Context

Phase 2 adds albums. The user chose that albums can be shared with other accounts of the same server,
each person being either a **viewer** or a **contributor** (adds their own photos), and later through a
public link. Until now, every record was readable by its owner only, and drive files must stay private.

## Decision

- **Collections.** `albums` (owner, name, cover → media, `members` and `contributors`: multi-relations to
  users) and `album_items` (album, media, added_by; unique per album). A person's role is the list they
  are in. Deleting an album, a photo or an account cascades.
- **Rules.** Albums are readable by their owner, members and contributors; only the owner changes or
  deletes them. Owners and contributors add items, **only their own photos**; an item is removed by the
  album owner or by whoever added it. When a contributor is removed (or leaves), their items go too.
- **Photos.** The `media` *view* rule also lets album participants read a photo that is in their album,
  through the `album_items_via_media` back-relation. The *list* rule stays owner-only, so timelines never
  mix accounts. Thumbnails and previews live on `media`, so every photo now gets its own derivatives
  (ffmpeg, or a pure-Go thumbnailer for JPEG/PNG/GIF/WebP).
- **Drive files stay owner-only.** Participants never read `nodes`. The original of a shared photo (video
  playback, download) is served by `GET /api/v1/media/{id}/original`, which checks the `media` view rule
  with `CanAccessRecord`, so there is one source of truth.
- **Custom reads** where rules cannot express it: album list with counts and covers, album items with
  file names, people of an album, and an exact-email account lookup to invite someone.

## Consequences

- ✅ Sharing never widens access to the drive; revoking a member takes effect immediately (rules and
  file tokens are checked on every request).
- ⚠️ Any signed-in user can check whether an email has an account on the server (exact match only,
  rate-limited). Acceptable for a personal or family server; revisit with invitations.
- ⚠️ Location data (EXIF GPS) of shared photos is visible to participants. A per-album "hide location"
  option is planned.
