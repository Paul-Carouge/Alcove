# 0002. Web client: SvelteKit static build embedded in the server

- Status: Accepted (2026-10-11)

## Context

We want a fast, polished web UI, shipped inside the server binary (no separate Node runtime in
production) and reusable by the desktop app.

## Decision

The web client is **SvelteKit (Svelte 5) built with `adapter-static`** as a single-page app (SSR off,
`index.html` fallback). The build is embedded in the Go binary with `go:embed` and served by PocketBase's
static handler. i18n uses Paraglide (compiled messages, EN + FR). Styling uses plain CSS with design-token
variables.

## Consequences

- ✅ No Node in production. One binary serves UI and API from the same origin (no CORS, strict CSP).
- ✅ Svelte's small bundles and compiled reactivity help keep the UI fast.
- ✅ The same build can be loaded by Tauri ([0003](0003-desktop-tauri.md)).
- ⚠️ No SSR: no SEO, and first paint waits for JS. Acceptable for an authenticated app.
- ⚠️ CSP needs SvelteKit's hash mode for its bootstrap script (configured in `vite.config.ts`).
