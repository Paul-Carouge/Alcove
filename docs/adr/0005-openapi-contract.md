# 0005. OpenAPI is the API contract; clients are generated

- Status: Accepted (2026-10-11)

## Context

Three clients (web, mobile, desktop) in two languages (TypeScript, Dart) call the server. Hand-written
clients drift from the server and from each other.

## Decision

`packages/api-spec/openapi.yaml` (OpenAPI 3.1) is the **source of truth for every custom endpoint**.
TypeScript types (`openapi-typescript` + `openapi-fetch`) and a Dart client (`openapi-generator`, in Docker)
are generated and committed. CI fails if they are stale. Workflow: spec → generate → server → clients,
in the same commit. PocketBase built-in routes are not re-described. Clients use the PocketBase SDKs for those.

## Consequences

- ✅ Typed clients, reviewable API changes (diffs on the spec), documentation for free.
- ✅ Compatibility is explicit: API version `N` in the spec, `/health` range, per-client range.
- ⚠️ Two client styles coexist: generated client for custom routes, PocketBase SDK for built-ins.
- ⚠️ The generated Dart code is verbose. We keep it as a separate package (`alcove_api`) and never edit it.
