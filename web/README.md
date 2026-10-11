# @alcove/web

SvelteKit (Svelte 5, runes) built as a static SPA and embedded in the server binary.

- `pnpm dev`: Vite on :5173, proxies `/health`, `/api`, `/_` to the Go server on :8090 (`make dev` starts both).
- `pnpm check` / `pnpm lint` / `pnpm test` / `pnpm build`.
- i18n: Paraglide, messages in `messages/{en,fr}.json` (keys must exist in both).
- Styles: only design tokens (`src/lib/styles/tokens.css`, generated) via CSS variables.
- Imports: `#lib/...` (Node subpath imports) with `.js` extensions for TS files.
