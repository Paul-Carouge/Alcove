# 0021. Mobile app: PocketBase Dart SDK, official Flutter packages, no framework

- Status: Accepted (2026-10-12). Builds on [0004](0004-mobile-flutter-user-server-url.md).

## Context

Phase 4 turns the mobile app from a connect screen into a client: sign-in with both second factors (email
codes and the Alcove authenticator), photos, files, and next automatic photo backup. The user left the
choice of approach to the maintainer.

## Decision

- **PocketBase Dart SDK** (`pocketbase`, MIT, official) for auth, records, file tokens and realtime, mirroring
  the web's JS SDK; the generated `alcove_api` client stays for custom routes that have one.
- The auth state goes through `AsyncAuthStore` into `SecureStore` (Keychain / Keystore) only.
- **Official Flutter packages only** for platform features: `video_player`, `url_launcher` (and later the
  background/backup plugins, each in its own ADR if not first-party).
- **No state-management or routing framework**: a `Session` `ChangeNotifier`, `IndexedStack` tabs, plain
  `Navigator`. The app is small; fewer dependencies are easier to keep current.
- Sign-in follows the web exactly: password, then `totpRequired` (authenticator or recovery code) or `mfaId`
  (email code via `requestOTP` / `authWithOTP`).

## Consequences

- ✅ Same server behaviour on web and mobile; rate limits, MFA and file tokens are shared.
- ✅ Few dependencies, all from Google or PocketBase.
- ⚠️ No disk cache for thumbnails yet (memory only); acceptable until offline use (later in phase 4).
- ⚠️ iOS builds need a full Xcode, not available on the maintainer machine yet: iOS is built in CI later.
