import { createApiClient, type components } from '@alcove/api-spec';
import { pb } from '#lib/pb.js';

/** A record of the `imports` collection (Google Photos import from Takeout, ADR 0030). */
export type ImportJob = components['schemas']['ImportJob'];
export type ImportFailure = NonNullable<ImportJob['failures']>[number];
export type ServerFile = { name: string; kind: 'zip' | 'folder'; size: number };
export type ImportUpload = components['schemas']['ImportUpload'];

export const TAKEOUT_URL = 'https://takeout.google.com/';

/** The wizard's steps: explain Takeout, choose archives, follow progress, read the report. */
export type ImportStep = 'intro' | 'source' | 'progress' | 'report';

const ACTIVE: ImportJob['status'][] = ['queued', 'scanning', 'running'];

export const isActive = (job: ImportJob | null | undefined) => !!job && ACTIVE.includes(job.status);

/** Which step to show for the user's latest job (a finished one shows its report until dismissed). */
export function stepOf(job: ImportJob | null, dismissed: string | null): ImportStep | null {
	if (!job) return null;
	if (isActive(job)) return 'progress';
	return dismissed === job.id ? null : 'report';
}

/** Progress in percent (0 while archives are read). */
export function percent(job: ImportJob): number {
	if (!job.total) return job.status === 'done' ? 100 : 0;
	return Math.min(100, Math.round((job.processed / job.total) * 100));
}

/** RFC 4180 field: quoted when needed; formula-like values neutralised for spreadsheets. */
function csvField(value: string): string {
	const safe = /^[=+\-@\t\r]/.test(value) ? `'${value}` : value;
	return /[",\n\r]/.test(safe) ? `"${safe.replaceAll('"', '""')}"` : safe;
}

/** The failures as CSV, with translated reasons. */
export function failuresCsv(
	failures: ImportFailure[],
	header: [string, string],
	reason: (code: ImportFailure['reason']) => string
): string {
	const rows = [header.map(csvField).join(',')];
	for (const f of failures) rows.push([f.path, reason(f.reason)].map(csvField).join(','));
	return rows.join('\r\n') + '\r\n';
}

/** Upload ids are the last segment of the tus upload URL. */
export function uploadIdOf(url: string): string {
	return url.replace(/\/+$/, '').split('/').pop() ?? '';
}

const api = () => createApiClient(window.location.origin);
const auth = () => ({ Authorization: pb.authStore.token });

export class ImportError extends Error {
	constructor(readonly status: number) {
		super(`import request failed: ${status}`);
	}
}

export async function latestImport(): Promise<ImportJob | null> {
	const res = await pb.collection('imports').getList<ImportJob>(1, 1, {
		sort: '-created',
		filter: pb.filter('owner = {:me}', { me: pb.authStore.record?.id })
	});
	return res.items[0] ?? null;
}

export async function startImport(body: {
	uploads?: string[];
	serverFiles?: string[];
	user?: string;
}): Promise<ImportJob> {
	const { data, response } = await api().POST('/api/v1/imports/google', { headers: auth(), body });
	if (!data) throw new ImportError(response.status);
	return data;
}

export async function cancelImport(id: string) {
	const { response } = await api().POST('/api/v1/imports/{importId}/cancel', {
		headers: auth(),
		params: { path: { importId: id } }
	});
	if (!response.ok && response.status !== 409) throw new ImportError(response.status);
}

export async function listServerFiles(): Promise<{ dir: string; items: ServerFile[] }> {
	const { data, response } = await api().GET('/api/v1/imports/google/server-files', {
		headers: auth()
	});
	if (!data) throw new ImportError(response.status);
	return data as { dir: string; items: ServerFile[] };
}

/** The caller's finished import archives no job uses yet (uploaded during an earlier visit). */
export async function listImportUploads(): Promise<ImportUpload[]> {
	const { data, response } = await api().GET('/api/v1/imports/google/uploads', { headers: auth() });
	if (!data) throw new ImportError(response.status);
	return data.items;
}

export async function deleteImportUpload(id: string) {
	const { response } = await api().DELETE('/api/v1/imports/google/uploads/{uploadId}', {
		headers: auth(),
		params: { path: { uploadId: id } }
	});
	if (!response.ok && response.status !== 404) throw new ImportError(response.status);
}

/** Keeps the newest of two versions of a job (PocketBase dates sort as text). */
export const newer = (current: ImportJob | null, next: ImportJob) =>
	!current || current.id !== next.id || (next.updated ?? '') >= (current.updated ?? '')
		? next
		: current;

/** Follows one job through realtime; returns the unsubscribe function. */
export async function watchImport(
	id: string,
	onChange: (job: ImportJob) => void
): Promise<() => void> {
	const col = pb.collection('imports');
	let latest: ImportJob | null = null;
	const apply = (j: ImportJob) => {
		const kept = newer(latest, j);
		if (kept !== latest) onChange((latest = kept));
	};
	const stop = await col.subscribe<ImportJob>(id, (e) => apply(e.record));
	// Changes made before the subscription started (a small import can finish meanwhile); a late answer
	// never replaces a newer event.
	col
		.getOne<ImportJob>(id)
		.then(apply)
		.catch(() => {});
	return stop;
}
