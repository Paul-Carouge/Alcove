# 0004. Mobile: Flutter, user enters their own server URL

- Status: Accepted (2026-10-11)

## Context

Every user runs their own server, so the store app cannot hard-code a backend. We need Android first
(Play Store) and iOS later, with good performance for photo grids and background backup.

## Decision

The mobile app is built with **Flutter**. On first launch, the user **types or scans (QR) the URL of their
server**. The app normalizes it (https by default), calls `GET /health`, verifies the API range, and only then
proceeds to login. Release builds require HTTPS. Secrets are stored with `flutter_secure_storage`
(Android Keystore / iOS Keychain). Theme and strings come from the shared design tokens and ARB files.

## Consequences

- ✅ One codebase for Android and iOS, good rendering performance for media grids.
- ✅ A clear, early error when the app and server versions are incompatible.
- ⚠️ No shared UI code with the web client. Visual consistency relies on shared tokens and the DESIGN doc.
- ⚠️ Users with self-signed certificates can't connect in release builds. We recommend Let's Encrypt or Tailscale.
  Supporting custom CAs is a possible later addition.
- ⚠️ Background work (auto-backup) must follow Android/iOS background-execution limits ([0010](0010-no-firebase-unifiedpush.md)).
