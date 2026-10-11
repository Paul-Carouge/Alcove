# 0013. Two-factor authentication: email OTP first, TOTP later in phase 1

- Status: Accepted (2026-10-11)

## Context

2FA must be optional and available in v1. PocketBase has built-in MFA that combines two different methods,
such as password plus a one-time code sent by email. It has no TOTP (authenticator app) support.

## Decision

1. Phase 1 starts by exposing **PocketBase MFA: password + email OTP**, configurable per instance by the admin
   and opt-in per user once user-level settings exist.
2. **TOTP** (RFC 6238, authenticator apps) is added **at the end of phase 1** as a custom module: an encrypted
   per-user secret, QR enrollment, recovery codes, and rate-limited verification plugged into the auth flow.

## Consequences

- ✅ 2FA is available early with no custom crypto code.
- ⚠️ Email OTP needs working SMTP and is weaker than TOTP (email account compromise). We document this.
- ⚠️ TOTP needs careful design (secret encryption key management, recovery). It gets its own spec and review.
