import PocketBase from 'pocketbase';

/**
 * Shared PocketBase client. Same origin as the web UI (embedded in the
 * server); the auth token lives in localStorage (ADR 0012).
 */
export const pb = new PocketBase(typeof window === 'undefined' ? '' : window.location.origin);

// Keep concurrent requests (e.g. several components loading) from cancelling each other.
pb.autoCancellation(false);
