import type { DetailedError, Upload, UploadOptions } from 'tus-js-client';
import { pb } from '#lib/pb.js';

export type UploadStatus = 'queued' | 'uploading' | 'done' | 'error' | 'quota' | 'canceled';

export interface UploadItem {
	id: number;
	name: string;
	size: number;
	parent: string;
	sent: number;
	status: UploadStatus;
	nodeId?: string;
}

const ENDPOINT = '/api/v1/uploads/';
const CHUNK_SIZE = 8 * 1024 * 1024; // below the server's 64 MiB per-request limit
const CONCURRENCY = 3;

// The tus client is only needed once something is uploaded: keep it out of the first page load.
let tus: Promise<typeof import('tus-js-client')> | null = null;
const loadTus = () => (tus ??= import('tus-js-client'));

/** Quota full, or the server's disk full (507): both shown as "Not enough space". */
const isQuota = (err: DetailedError) =>
	err.originalResponse?.getStatus() === 507 ||
	(err.originalResponse?.getStatus() === 413 &&
		(err.originalResponse.getBody() ?? '').startsWith('ERR_QUOTA_EXCEEDED'));

/** Retry network errors, timeouts, conflicts and rate limits; not other client errors. */
function shouldRetry(err: DetailedError): boolean {
	const status = err.originalResponse?.getStatus() ?? 0;
	return (
		status === 0 ||
		status === 409 ||
		status === 423 ||
		status === 429 ||
		(status >= 500 && status !== 507)
	);
}

/**
 * Upload queue (tus, ADR 0011). Interrupted uploads resume from the last
 * stored chunk, even after a page reload when the same file is picked again.
 */
class UploadQueue {
	items = $state<UploadItem[]>([]);
	#files = new Map<number, File>();
	/** null while the tus client loads. */
	#running = new Map<number, Upload | null>();
	#nextId = 1;

	get active() {
		return this.items.filter((i) => i.status === 'queued' || i.status === 'uploading');
	}

	add(files: Iterable<File>, parent: string) {
		for (const file of files) {
			const id = this.#nextId++;
			this.#files.set(id, file);
			this.items.push({ id, name: file.name, size: file.size, parent, sent: 0, status: 'queued' });
		}
		this.#pump();
	}

	cancel(id: number) {
		const item = this.#item(id);
		if (!item || (item.status !== 'queued' && item.status !== 'uploading')) return;
		this.#running.get(id)?.abort(true); // true: also delete the partial upload on the server
		this.#running.delete(id);
		item.status = 'canceled';
		this.#pump();
	}

	retry(id: number) {
		const item = this.#item(id);
		if (!item || !['error', 'quota', 'canceled'].includes(item.status)) return;
		item.status = 'queued';
		this.#pump();
	}

	clearFinished() {
		this.items = this.items.filter((i) => i.status === 'queued' || i.status === 'uploading');
		for (const id of this.#files.keys()) if (!this.#item(id)) this.#files.delete(id);
	}

	#item(id: number) {
		return this.items.find((i) => i.id === id);
	}

	#pump() {
		while (this.#running.size < CONCURRENCY) {
			const next = this.items.find((i) => i.status === 'queued');
			if (!next) return;
			this.#start(next);
		}
	}

	#start(item: UploadItem) {
		const file = this.#files.get(item.id);
		if (!file) return;
		item.status = 'uploading';

		const options: UploadOptions = {
			endpoint: ENDPOINT,
			chunkSize: CHUNK_SIZE,
			retryDelays: [0, 1000, 3000, 5000, 10000, 20000],
			metadata: { filename: file.name, parent: item.parent },
			removeFingerprintOnSuccess: true,
			// The token can be refreshed during a long upload: read it per request.
			onBeforeRequest: (req) => req.setHeader('Authorization', pb.authStore.token),
			onShouldRetry: (err) => shouldRetry(err as DetailedError),
			onProgress: (sent) => (item.sent = sent),
			onSuccess: ({ lastResponse }) => {
				item.sent = item.size;
				item.status = 'done';
				item.nodeId = lastResponse.getHeader('Alcove-Node-Id') ?? undefined;
				this.#finish(item.id);
			},
			onError: (err) => {
				if (item.status !== 'canceled')
					item.status = isQuota(err as DetailedError) ? 'quota' : 'error';
				this.#finish(item.id);
			}
		};
		this.#running.set(item.id, null);
		loadTus()
			.then(({ Upload }) => {
				if (item.status !== 'uploading') return; // canceled while loading
				const upload = new Upload(file, options);
				this.#running.set(item.id, upload);
				return upload.findPreviousUploads().then((previous) => {
					const sameFolder = previous.find((p) => p.metadata.parent === item.parent);
					if (sameFolder) upload.resumeFromPreviousUpload(sameFolder);
					upload.start();
				});
			})
			.catch(() => {
				item.status = 'error';
				this.#finish(item.id);
			});
	}

	#finish(id: number) {
		this.#running.delete(id);
		this.#pump();
	}
}

export const uploads = new UploadQueue();
