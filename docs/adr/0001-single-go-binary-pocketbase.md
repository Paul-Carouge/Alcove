# 0001. Single Go binary built on PocketBase

- Status: Accepted (2026-10-11)

## Context

Self-hosters want something that is easy to install, light on resources and easy to back up. A classic
stack (API server + Postgres + Redis + worker + object store) multiplies moving parts. We need auth,
CRUD with access rules, realtime and file handling from day one, built by a small team.

## Decision

The server is **one Go binary** built on **PocketBase used as a framework** (Go package, not the
prebuilt binary). It provides auth (password, OTP, MFA, OAuth2), collections with API rules, SSE realtime,
file storage (local/S3), backups, an admin UI and migrations. We add custom routes, hooks and jobs in
Go and embed the web UI. The database is SQLite.

## Consequences

- ✅ One process, one data directory, trivial backups, runs on a Raspberry Pi.
- ✅ Much less code to write and secure for auth/CRUD/realtime.
- ⚠️ SQLite means a single writer and vertical scaling only. That is fine for personal/family/small-team
  instances, which is the target. Not a multi-tenant SaaS architecture.
- ⚠️ PocketBase is pre-1.0 with occasional breaking changes. We pin versions and upgrade deliberately
  (Renovate requires approval), and keep our code behind small `internal/*` packages.
- ⚠️ Built-in routes follow PocketBase's API shape. Our own routes follow our OpenAPI spec ([0005](0005-openapi-contract.md)).
