import type { RecordSubscription } from 'pocketbase';
import { pb } from '#lib/pb.js';
import type { DriveNode } from './types.js';

type Handler = (event: RecordSubscription<DriveNode>) => void;

const handlers = new Set<Handler>();
let unsubscribe: (() => Promise<void>) | null = null;

/**
 * One realtime subscription to `nodes` for the whole app, fanned out to views.
 * (Per-view subscribe/unsubscribe on the same topic within one tick loses the
 * new listener in the PocketBase SDK.)
 */
export function onNodeChange(handler: Handler): () => void {
	handlers.add(handler);
	if (!unsubscribe) {
		const pending = pb
			.collection<DriveNode>('nodes')
			.subscribe('*', (event) => handlers.forEach((h) => h(event)));
		unsubscribe = () => pending.then((unsub) => unsub());
	}
	return () => {
		handlers.delete(handler);
	};
}

/** Closes the subscription (on sign-out). */
export async function stopLiveUpdates() {
	handlers.clear();
	const stop = unsubscribe;
	unsubscribe = null;
	await stop?.();
}
