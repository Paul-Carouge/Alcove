# 0019. Public album links

- Status: Accepted (2026-10-12). Extends the file share links (v0.5) and [0018](0018-albums-and-sharing-between-accounts.md).

## Context

The user wants albums to be shareable with people who have no account, like files: a link, optionally
protected by a password and an expiry. Photos carry private metadata (GPS position, camera serial numbers),
and visitors are anonymous.

## Decision

- **Same mechanism as file links.** A `shares` record now points to a node **or** an album (exactly one).
  The token is shown once and stored as a SHA-256; password, expiry, rate limits and revocation (Shared page)
  work the same. Only the album **owner** can create a link; deleting the album deletes its links.
- **Privacy first.** The public listing exposes no location, camera or lens data. Photos are served only as
  the generated thumbnail and preview, which are re-encoded JPEGs without metadata; **original photos are
  never served** through album links. Videos are streamed from the original file (there is no transcode yet),
  so their embedded metadata is reachable by visitors; this is stated in the share dialog.
- **Live content.** A link shows the album as it is now: photos added later appear, removed or trashed ones
  disappear.

## Consequences

- ✅ One sharing model to explain, audit and test.
- ✅ Sharing an album never exposes where its photos were taken.
- ⚠️ Visitors cannot download full-resolution photos. An opt-in "allow downloads" option could come later.
- ⚠️ Video metadata leaks until videos get stripped transcodes.
