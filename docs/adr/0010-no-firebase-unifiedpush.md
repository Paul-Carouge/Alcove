# 0010. No Firebase; sync on open and periodically, UnifiedPush optional

- Status: Accepted (2026-10-11)

## Context

Push notifications on Android usually go through Firebase Cloud Messaging, which requires a Google
project tied to the app publisher and routes metadata through Google. Self-hosted servers can't
share a publisher's FCM credentials safely, and many users avoid Google services.

## Decision

**No Firebase.** Mobile apps sync **when opened** and in **periodic background tasks** (WorkManager on
Android, BGTaskScheduler on iOS). Optional real-time wake-ups use **UnifiedPush** (for example a
self-hosted **ntfy**): the server sends to the distributor endpoint registered by the device.

## Consequences

- ✅ No Google dependency, works on de-Googled Android, no shared secrets.
- ✅ Simpler privacy story.
- ⚠️ Without UnifiedPush, notifications are delayed until the next sync window.
- ⚠️ iOS has no UnifiedPush equivalent. iOS background sync is best-effort, and APNs could be revisited later.
