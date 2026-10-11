# Architecture Decision Records

One file per significant decision: context, decision, consequences. Records are immutable once
accepted. To change a decision, add a new ADR that supersedes the old one.

| # | Decision | Status |
|---|---|---|
| [0001](0001-single-go-binary-pocketbase.md) | Single Go binary built on PocketBase | Accepted |
| [0002](0002-web-sveltekit-static.md) | Web client: SvelteKit static build embedded in the server | Accepted |
| [0003](0003-desktop-tauri.md) | Desktop: Tauri reusing the web UI, Rust sync engine | Accepted |
| [0004](0004-mobile-flutter-user-server-url.md) | Mobile: Flutter, user enters their own server URL | Accepted |
| [0005](0005-openapi-contract.md) | OpenAPI is the API contract; clients are generated | Accepted |
| [0006](0006-storage-local-default-s3-optional.md) | Storage: local disk by default, S3 optional | Accepted |
| [0007](0007-optional-module-containers.md) | OCR and face recognition as optional containers | Accepted |
| [0008](0008-docker-compose-caddy.md) | Deployment: docker compose with Caddy | Accepted |
| [0009](0009-no-e2ee-in-v1.md) | No end-to-end encryption in v1 | Accepted |
| [0010](0010-no-firebase-unifiedpush.md) | No Firebase; sync on open and periodically, UnifiedPush optional | Accepted |

Template: copy an existing ADR. Sections: Status, Context, Decision, Consequences.
