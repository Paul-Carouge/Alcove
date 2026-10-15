import type { RecordModel, RecordSubscription } from 'pocketbase';
import { pb } from '#lib/pb.js';
import type { DriveNode } from './types.js';

type Handler<T> = (event: RecordSubscription<T>) => void;

/**
 * One realtime subscription per collection for the whole app, fanned out to
 * views. (Per-view subscribe/unsubscribe on the same topic within one tick
 * loses the new listener in the PocketBase SDK.)
 */
function channel<T extends RecordModel>(collection: string) {
	const handlers = new Set<Handler<T>>();
	let stop: (() => Promise<void>) | null = null;
	return {
		on(handler: Handler<T>): () => void {
			handlers.add(handler);
			if (!stop) {
				const pending = pb
					.collection<T>(collection)
					.subscribe('*', (event) => handlers.forEach((h) => h(event)));
				stop = () => pending.then((unsub) => unsub());
			}
			return () => {
				handlers.delete(handler);
			};
		},
		async close() {
			handlers.clear();
			const s = stop;
			stop = null;
			await s?.();
		}
	};
}

const nodes = channel<DriveNode>('nodes');
const mediaChannel = channel<RecordModel>('media');
const albumChannel = channel<RecordModel>('albums');
const albumItemChannel = channel<RecordModel>('album_items');
const documentChannel = channel<RecordModel>('documents');
const noteChannel = channel<RecordModel>('notes');
const calendarChannel = channel<RecordModel>('calendars');
const eventChannel = channel<RecordModel>('events');

export const onNodeChange = (h: Handler<DriveNode>) => nodes.on(h);
export const onMediaChange = <T extends RecordModel>(h: Handler<T>) =>
	mediaChannel.on(h as Handler<RecordModel>);

export const onAlbumChange = (h: Handler<RecordModel>) => albumChannel.on(h);
export const onAlbumItemChange = (h: Handler<RecordModel>) => albumItemChannel.on(h);
export const onDocumentChange = (h: Handler<RecordModel>) => documentChannel.on(h);
export const onNoteChange = <T extends RecordModel>(h: Handler<T>) =>
	noteChannel.on(h as Handler<RecordModel>);
export const onCalendarChange = <T extends RecordModel>(h: Handler<T>) =>
	calendarChannel.on(h as Handler<RecordModel>);
export const onEventChange = <T extends RecordModel>(h: Handler<T>) =>
	eventChannel.on(h as Handler<RecordModel>);

/** Closes every subscription (on sign-out). */
export async function stopLiveUpdates() {
	await Promise.all([
		nodes.close(),
		mediaChannel.close(),
		albumChannel.close(),
		albumItemChannel.close(),
		documentChannel.close(),
		noteChannel.close(),
		calendarChannel.close(),
		eventChannel.close()
	]);
}
