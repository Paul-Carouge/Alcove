# CLAUDE.md

Guidance for AI agents (and humans) working in this repository.

## Project

Alcove (working name) is a self-hosted personal cloud: file drive, photos/videos, documents with OCR,
later notes/calendar/contacts. Goals: beautiful, simple to deploy, realtime, secure. License AGPL-3.0-only.

| Path | What | Stack |
|---|---|---|
| `server/` | Single binary: PocketBase (auth, CRUD, SSE realtime) + custom routes + embedded web UI | Go 1.27, PocketBase 0.40 |
| `web/` | Web client, static SPA embedded in the server | SvelteKit 3 / Svelte 5 runes, Paraglide i18n |
| `mobile/` | Android/iOS client; user enters their own server URL | Flutter 3.44 |
| `desktop/` | Placeholder (phase 6): Tauri shell + Rust folder sync | |
| `packages/api-spec/` | `openapi.yaml`, the contract for custom endpoints; generated TS + Dart clients | OpenAPI 3.1 |
| `packages/design-tokens/` | `tokens.json` → `web/src/lib/styles/tokens.css` + `mobile/lib/theme/tokens.g.dart` | Node script |
| `deploy/` | Dockerfile (distroless), `docker-compose.yml` (server + Caddy), Caddyfile | |
| `docs/` | Architecture, design, security, self-hosting, roadmap, ADRs (`docs/adr/`) | |

Read `docs/ARCHITECTURE.md` before structural changes and `docs/DESIGN.md` before UI work.

## Commands

Everything from the repo root via `make` (`make help` lists targets).

```sh
make setup        # pnpm install, go mod download, flutter pub get, pre-commit hooks
make dev          # server on :8090 + Vite on :5173 (proxies /health, /api, /_)
make lint         # all linters      | make lint-server / lint-web / lint-packages / lint-mobile
make test         # all tests        | make test-server / test-web / test-packages / test-mobile
make gen          # regenerate API clients (needs Docker) + design tokens
make check-gen    # fail if generated files are stale
make build        # server/bin/alcove with web UI embedded
make docker       # build the image; `cd deploy && docker compose up -d` to run the stack
```

Per package, if needed:
- server: `cd server && go test ./... && golangci-lint run ./...`
- web: `pnpm --filter @alcove/web {check,lint,test,build}`
- mobile: `cd mobile && flutter gen-l10n && flutter analyze && flutter test`
- tokens: `pnpm --filter @alcove/design-tokens {build,check,test}`
- api-spec: `pnpm --filter @alcove/api-spec {lint,gen}`

Dev data lives in `server/pb_data/` (git-ignored). Admin UI: http://127.0.0.1:8090/_/

## Working rules

1. **Small commits**, Conventional Commits, enforced by commitlint:
   `type(scope): subject`. Scopes: server, web, mobile, desktop, api-spec, design-tokens, deploy, docs, ci, deps, release.
2. **Run lint and tests of every package you touched before saying you are done.** Report failures honestly.
3. **Never change the HTTP API without updating `packages/api-spec/openapi.yaml` first**, then `make gen`,
   then server handler + tests, then clients. Spec, generated clients and server change in the same commit.
4. **Ask before major architecture choices** (new dependency of significance, new service/container,
   storage or auth model changes, anything contradicting an ADR). Record accepted decisions as a new ADR.
5. Never edit generated files: `packages/api-spec/clients/**`, `web/src/lib/styles/tokens.css`,
   `mobile/lib/theme/tokens.g.dart`, `mobile/lib/l10n/gen/`, `web/src/lib/paraglide/`.
6. Database changes only through Go migrations in `server/migrations/` (timestamp prefix, `up` **and**
   `down`, both tested). Never edit a migration that has been released.
7. Never modify original photos/videos. Derivatives (thumbnails, transcodes) are separate files.
8. Never commit secrets. Credentials come from env (`ALCOVE_*`) or the admin UI.

## Conventions

**General**
- Product name is never hard-coded outside: `server/internal/buildinfo` (`Name`), `web/src/lib/brand.ts`,
  `mobile/lib/core/brand.dart`, Android/iOS app labels, and the package/module names. Clients prefer
  the `name` returned by `/health`.
- Env vars are prefixed `ALCOVE_` (see `server/internal/config`, `.env.example`).
- All user-facing strings are translated (EN + FR) from day one. No string literals in UI code.
- Accessibility is a requirement, not polish: WCAG 2.2 AA, keyboard navigation, focus visible,
  screen-reader labels, 44px (web) / 48dp (mobile) touch targets, `prefers-reduced-motion` respected.

**Go (server)**
- `internal/<feature>` packages, each exposing `Register(app core.App, ...)` that binds hooks/routes.
- Custom routes under `/api/v{N}/…` (except `/health`). Validate all input strictly; return PocketBase
  `e.BadRequestError` style errors (`{status, message, data}`).
- Authorization through PocketBase collection rules or `apis.RequireAuth()`; never trust client IDs.
- Tests use `github.com/pocketbase/pocketbase/tests` (`ApiScenario`). Table-driven tests for pure logic.
- `gofmt`/`goimports` with local prefix `github.com/Paul-Carouge/Alcove`.

**Web**
- Svelte 5 runes only (`$state`, `$derived`, `$effect`, `$props`). TypeScript strict.
- Imports via `#lib/...` with `.js` extension for TS files (Node subpath imports).
- Styling: plain CSS in components, values **only** from token variables (`var(--space-4)`, `var(--color-text)`).
  No hex colors or magic px in components.
- API calls through `@alcove/api-spec` (`createApiClient`); PocketBase built-ins through the PocketBase JS SDK (to add in phase 1).
- Prettier: tabs, single quotes, width 100.

**Flutter**
- Widgets read colors via `context.colors` and spacing/radii from `AlcoveSpace`/`AlcoveRadius`.
- Strings in `lib/l10n/app_{en,fr}.arb`. Sealed classes + pattern matching for results/states.
- Tokens and secrets only via `SecureStore` (Keystore/Keychain). HTTPS required; http allowed in debug builds only.
- Layout: `lib/core/` (non-UI logic), `lib/features/<feature>/` (screens), `lib/theme/`.

## Gotchas

- Dart client generation runs openapi-generator in Docker (`packages/api-spec/scripts/gen-dart.sh`).
- `pnpm --filter @alcove/web check` compiles Paraglide first; messages must exist in both `en.json` and `fr.json`.
- The web CSP is one header built by `server/internal/security`; its `script-src` (with SvelteKit's
  inline-script hashes) is read from the embedded `index.html` at boot (`webui.ScriptSrc`). Browsers
  enforce header **and** meta CSPs together, so never add a second, stricter policy. Inline scripts or
  third-party origins are blocked by design.
- Rate limits are enabled by migration `1791676800_security_defaults.go` and tunable in the admin UI.
- PocketBase is pre-1.0: upgrades can break things. Read its changelog, bump deliberately (Renovate requires approval).
