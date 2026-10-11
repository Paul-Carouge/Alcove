# 0012. Web session token stored in localStorage

- Status: Accepted (2026-10-11)

## Context

The web client authenticates with PocketBase JWTs. They can be kept in `localStorage` (the PocketBase JS SDK
default) or in an HttpOnly cookie set by a custom route. Cookies hide the token from JavaScript but need CSRF
protection and a custom auth flow. The same UI will also run inside Tauri.

## Decision

Use the **PocketBase JS SDK with its default `LocalAuthStore` (localStorage)**. Defense against token theft
relies on preventing XSS: a strict CSP (no inline or third-party scripts, see `server/internal/security`),
Svelte's escaping, no `{@html}` with user content, and user files never served as active content from the app origin.

## Consequences

- ✅ Standard SDK behavior, works identically in browsers and Tauri, no CSRF surface.
- ✅ Simple realtime subscriptions (the SDK sends the token itself).
- ⚠️ Any XSS could exfiltrate the token. The CSP and content-serving rules are therefore security-critical and covered by tests.
- ⚠️ Revisit if we ever need to embed third-party scripts (we don't plan to).
