# 0009. No end-to-end encryption in v1

- Status: Accepted (2026-10-11)

## Context

End-to-end encryption (E2EE) protects data from the server operator. But in a self-hosted product the
operator is usually the user. E2EE would also prevent server-side features that are core to the product:
thumbnails, video transcoding, OCR, full-text search, face recognition, previews and public share links.

## Decision

**No E2EE in v1.** Data is protected in transit (TLS) and by access control. Encryption at rest is left
to the host (LUKS, encrypted ZFS) or to the S3 provider. We keep E2EE as a **future opt-in option** (for
example encrypted "vault" folders that give up server-side processing) and avoid designs that would make
it impossible, such as relying on plaintext file names in storage keys.

## Consequences

- ✅ Full feature set (search, OCR, thumbnails, sharing) with a simpler, safer implementation.
- ⚠️ A compromised server or a malicious admin can read data. This is stated in the threat model.
- ⚠️ Users who need protection from their host must use disk encryption or wait for vaults.
