# @alcove/api-spec

`openapi.yaml` is the source of truth for every custom server endpoint.
Clients are generated from it and committed, so building a client never needs Docker or Java.

| Output | Consumer | Command |
|---|---|---|
| `clients/ts/schema.d.ts` (+ hand-written `index.ts`) | `/web`, `/desktop` | `pnpm gen:ts` |
| `clients/dart/` (`alcove_api` package) | `/mobile` | `pnpm gen:dart` (needs Docker) |

Workflow: edit `openapi.yaml` → `pnpm lint` → `pnpm gen` → update server handler + tests → commit all together.
CI fails if the generated clients are out of date.

Bump `CLIENT_API_RANGE` (TS) / `kClientApiRange` (Dart, in `/mobile`) and the server's
`api.max` together when introducing a new API version.
