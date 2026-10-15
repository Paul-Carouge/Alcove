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
| [0007](0007-optional-module-containers.md) | OCR and face recognition as optional containers | Accepted (OCR superseded by 0025) |
| [0008](0008-docker-compose-caddy.md) | Deployment: docker compose with Caddy | Accepted |
| [0009](0009-no-e2ee-in-v1.md) | No end-to-end encryption in v1 | Accepted |
| [0010](0010-no-firebase-unifiedpush.md) | No Firebase; sync on open and periodically, UnifiedPush optional | Accepted |
| [0011](0011-resumable-uploads-tus.md) | Resumable uploads with tus (tusd embedded) | Accepted |
| [0012](0012-web-token-localstorage.md) | Web session token in localStorage | Accepted |
| [0013](0013-2fa-email-otp-then-totp.md) | 2FA: email OTP first, TOTP later in phase 1 | Accepted |
| [0014](0014-native-install-docker-optional.md) | Native single-binary install first, Docker optional | Accepted |
| [0015](0015-signed-self-updates.md) | Self-updates from signed releases (CLI, web, mobile) | Accepted |
| [0016](0016-bundled-ffmpeg.md) | ffmpeg bundled, not an optional container | Accepted |
| [0017](0017-ffmpeg-bundle-for-native-linux.md) | Native Linux installs get Alcove's own ffmpeg | Accepted |
| [0018](0018-albums-and-sharing-between-accounts.md) | Albums, and sharing them between accounts | Accepted |
| [0019](0019-public-album-links.md) | Public album links | Accepted |
| [0020](0020-photo-map.md) | Photo map: offline basemap, optional OpenStreetMap tiles | Accepted |
| [0021](0021-mobile-app-stack.md) | Mobile app: PocketBase Dart SDK, official Flutter packages, no framework | Accepted |
| [0022](0022-mobile-photo-backup.md) | Mobile photo backup | Accepted |
| [0023](0023-android-distribution.md) | Android app: signed APK in every release, http on private networks | Accepted |
| [0024](0024-in-app-updates.md) | Mobile app updates itself from its server | Accepted |
| [0025](0025-documents-and-ocr.md) | Documents: text extraction and OCR shipped like ffmpeg | Accepted |
| [0026](0026-mobile-files-and-scanning.md) | Mobile: sending files with the system picker, scanning with ML Kit | Accepted |
| [0027](0027-notes-in-the-database.md) | Notes are stored in the database, not as Markdown files | Accepted |
| [0028](0028-calendar-model.md) | Calendar: events in the database, shaped like iCalendar; CalDAV later | Accepted |

Template: copy an existing ADR. Sections: Status, Context, Decision, Consequences.
