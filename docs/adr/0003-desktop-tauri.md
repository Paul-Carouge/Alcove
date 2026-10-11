# 0003. Desktop: Tauri reusing the web UI, Rust sync engine

- Status: Accepted (2026-10-11), implementation in phase 6

## Context

Desktop users expect folder sync (like Dropbox/Nextcloud) and a native-feeling app, without shipping a
Chromium per app.

## Decision

The desktop app uses **Tauri 2**. It loads the SvelteKit build from `/web`, and the **folder sync engine is
written in Rust** inside the Tauri backend. It talks to the server through the same HTTP API.

## Consequences

- ✅ Small binaries (system webview), one UI codebase for web and desktop.
- ✅ Rust is a good fit for a robust, concurrent file-watching and sync engine.
- ⚠️ System webviews differ (WebKitGTK on Linux), so the web UI must avoid bleeding-edge APIs or feature-detect.
- ⚠️ The web UI must not assume same-origin when running inside Tauri: the API base URL becomes configurable,
  and CORS must allow the Tauri origin.
