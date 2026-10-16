import type { DetailedError, Upload } from 'tus-js-client';
import { pb } from '#lib/pb.js';
import { deleteImportUpload, uploadIdOf, type ImportUpload } from './takeout.js';

export type ArchiveStatus = 'queued' | 'uploading' | 'done' | 'error' | 'disk' | 'limit';

export interface Archive {
	key: number;
	name: string;
	size: number;
	sent: number;
	status: ArchiveStatus;
	/** The server's upload id, once the archive is complete. */
	id?: string;
	/** Included in the next import. */
	selected: boolean;
	/** Uploaded during an earlier visit. */
	stored?: boolean;
}

const ENDPOINT = '/api/v1/uploads/';
const CHUNK_SIZE = 32 * 1024 * 1024; // below the server's 64 MiB per-request limit

const statusOf = (err: DetailedError) => err.originalResponse?.getStatus() ?? 0;
const failureOf = (err: DetailedError): ArchiveStatus =>
	statusOf(err) === 507 ? 'disk' : statusOf(err) === 413 ? 'limit' : 'error';

/**
 * Takeout archives (several 2–50 GB zips), sent one after the other with tus: an interrupted upload
 * resumes where it stopped, also after a reload when the same file is picked again.
 */
export class ArchiveUploads {
	items = $state<Archive[]>([]);
	// eslint-disable-next-line svelte/prefer-svelte-reactivity -- File handles, never rendered
	#files = new Map<number, File>();
	#current: Upload | null = null;
	#next = 1;

	get busy() {
		return this.items.some((a) => a.status === 'queued' || a.status === 'uploading');
	}
	get ready() {
		return !this.busy && this.ids.length > 0;
	}
	get ids() {
		return this.items.flatMap((a) => (a.id && a.selected && a.status === 'done' ? [a.id] : []));
	}

	/** Shows archives uploaded during an earlier visit (finished, not used yet). */
	load(stored: ImportUpload[]) {
		for (const u of stored) {
			if (this.items.some((a) => a.id === u.id)) continue;
			const key = this.#next++;
			this.items.push({
				key,
				name: u.name,
				size: u.size,
				sent: u.size,
				status: 'done',
				id: u.id,
				selected: true,
				stored: true
			});
		}
	}

	add(files: Iterable<File>) {
		for (const file of files) {
			if (this.items.some((a) => a.name === file.name && a.size === file.size)) continue;
			const key = this.#next++;
			this.#files.set(key, file);
			this.items.push({
				key,
				name: file.name,
				size: file.size,
				sent: 0,
				status: 'queued',
				selected: true
			});
		}
		this.#pump();
	}

	/** Removes an archive from the list, and from the server once uploaded (frees the space). */
	remove(key: number) {
		const item = this.items.find((a) => a.key === key);
		if (item?.status === 'uploading') {
			this.#current?.abort(true);
			this.#current = null;
		}
		if (item?.id) deleteImportUpload(item.id).catch(() => {});
		this.items = this.items.filter((a) => a.key !== key);
		this.#files.delete(key);
		this.#pump();
	}

	retry(key: number) {
		const item = this.items.find((a) => a.key === key);
		if (item && ['error', 'disk', 'limit'].includes(item.status)) item.status = 'queued';
		this.#pump();
	}

	/** Stops the running upload (leaving the page); it resumes when the file is picked again. */
	pause() {
		this.#current?.abort(false);
		this.#current = null;
	}

	#pump() {
		if (this.#current || this.items.some((a) => a.status === 'uploading')) return;
		const item = this.items.find((a) => a.status === 'queued');
		if (!item) return;
		const file = this.#files.get(item.key);
		if (!file) return;
		item.status = 'uploading';
		import('tus-js-client')
			.then(async ({ Upload }) => {
				const upload = new Upload(file, {
					endpoint: ENDPOINT,
					chunkSize: CHUNK_SIZE,
					retryDelays: [0, 1000, 3000, 5000, 10000, 20000, 60000],
					metadata: { filename: file.name, purpose: 'import' },
					removeFingerprintOnSuccess: true,
					onBeforeRequest: (req) => req.setHeader('Authorization', pb.authStore.token),
					onShouldRetry: (err) => {
						const status = (err as DetailedError).originalResponse?.getStatus() ?? 0;
						return (
							status === 0 ||
							status === 409 ||
							status === 423 ||
							status === 429 ||
							(status >= 500 && status !== 507)
						);
					},
					onProgress: (sent) => (item.sent = sent),
					onSuccess: () => {
						item.sent = item.size;
						item.status = 'done';
						item.id = uploadIdOf(upload.url ?? '');
						this.#done(upload);
					},
					onError: (err) => {
						if (this.items.includes(item)) item.status = failureOf(err as DetailedError);
						this.#done(upload);
					}
				});
				const previous = await upload.findPreviousUploads();
				// Removed while the tus client loaded: never start it, and leave the queue alone (remove()
				// already moved on to the next archive).
				if (!this.items.includes(item) || item.status !== 'uploading') return;
				this.#current = upload;
				const same = previous.find((p) => p.metadata.purpose === 'import');
				if (same) upload.resumeFromPreviousUpload(same);
				upload.start();
			})
			.catch(() => {
				if (!this.items.includes(item)) return;
				item.status = 'error';
				this.#done(null);
			});
	}

	/** An upload ended: move on, unless another one already took its place. */
	#done(upload: Upload | null) {
		if (this.#current !== upload) return;
		this.#current = null;
		this.#pump();
	}
}
