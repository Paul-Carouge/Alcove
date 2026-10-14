import { createApiClient, type components } from '@alcove/api-spec';
import type { RecordModel } from 'pocketbase';
import type { DriveNode } from '#lib/drive/types.js';
import { pb } from '#lib/pb.js';

export type OCRStatus = components['schemas']['OCRStatus'];
export type SearchableJob = components['schemas']['SearchableJob'];
export type SearchHit = Omit<components['schemas']['SearchHit'], 'node'> & { node: DriveNode };

/** A record of the `documents` collection (ADR 0025). */
export interface DocumentRecord extends RecordModel {
	node: string;
	kind: 'pdf' | 'text' | 'image';
	status: 'pending' | 'ready' | 'skipped' | 'failed';
	method: '' | 'text' | 'pdf' | 'ocr';
	reason: string;
	text: string;
	pages: number;
	updated: string;
	expand?: { node?: DriveNode };
}

const api = () => createApiClient(window.location.origin);
const auth = () => ({ Authorization: pb.authStore.token });

export class DocumentsError extends Error {
	constructor(readonly status: number) {
		super(`documents request failed: ${status}`);
	}
}

/** Files and folders by name, then documents by their text (GET /api/v1/search). */
export async function search(q: string, signal?: AbortSignal): Promise<SearchHit[]> {
	const { data, response } = await api().GET('/api/v1/search', {
		headers: auth(),
		params: { query: { q } },
		signal
	});
	if (!data) throw new DocumentsError(response.status);
	return data.items as SearchHit[];
}

export type DocumentFilter = 'all' | 'pdf' | 'image' | 'text';

/** Documents shown on the Documents page: PDFs, text files, and images in which text was found. */
export function documentsFilter(kind: DocumentFilter, tag = ''): string {
	let f = `node.trashed_at = "" && (kind != "image" || (status = "ready" && text != ""))`;
	if (kind !== 'all') f += ` && kind = "${kind}"`;
	if (tag) f += pb.filter(' && node.tags.id ?= {:tag}', { tag });
	return f;
}

export async function listDocuments(kind: DocumentFilter, page = 1, perPage = 50, tag = '') {
	return pb.collection('documents').getList<DocumentRecord>(page, perPage, {
		filter: documentsFilter(kind, tag),
		sort: '-updated',
		expand: 'node',
		// The full text can be long: only an excerpt in lists.
		fields: '*,text:excerpt(220,true),expand.node'
	});
}

export async function documentText(id: string): Promise<string> {
	const rec = await pb.collection('documents').getOne<DocumentRecord>(id, { fields: 'text' });
	return rec.text;
}

export async function getOCR(): Promise<OCRStatus> {
	const { data, response } = await api().GET('/api/v1/admin/ocr', { headers: auth() });
	if (!data) throw new DocumentsError(response.status);
	return data;
}

export async function setOCR(enabled: boolean): Promise<OCRStatus> {
	const { data, response } = await api().PUT('/api/v1/admin/ocr', {
		headers: auth(),
		body: { enabled }
	});
	if (!data) throw new DocumentsError(response.status);
	return data;
}

export async function installOCR(): Promise<OCRStatus> {
	const { data, response } = await api().POST('/api/v1/admin/ocr/install', { headers: auth() });
	if (!data) throw new DocumentsError(response.status);
	return data;
}

/** Starts making a searchable copy of a scan ("<name> (OCR).pdf", made in the background). */
export async function makeSearchable(nodeId: string): Promise<SearchableJob> {
	const { data, response } = await api().POST('/api/v1/documents/{nodeId}/searchable', {
		headers: auth(),
		params: { path: { nodeId } }
	});
	if (!data) throw new DocumentsError(response.status);
	return data;
}

export async function searchableStatus(nodeId: string): Promise<SearchableJob> {
	const { data, response } = await api().GET('/api/v1/documents/{nodeId}/searchable', {
		headers: auth(),
		params: { path: { nodeId } }
	});
	if (!data) throw new DocumentsError(response.status);
	return data;
}
