import { pb } from '#lib/pb.js';
import type { DriveNode } from './types.js';

const nodes = () => pb.collection<DriveNode>('nodes');

/** Non-trashed children of a folder ('' = root). Access rules scope it to the user. */
export function listChildren(parent: string) {
	return nodes().getFullList({
		filter: pb.filter('parent = {:parent} && trashed_at = ""', { parent }),
		batch: 500
	});
}

export function getNode(id: string) {
	return nodes().getOne(id);
}

/** Ancestors from the root down to (and including) the given folder. */
export async function pathTo(folderId: string): Promise<DriveNode[]> {
	const chain: DriveNode[] = [];
	let id = folderId;
	for (let depth = 0; id && depth < 64; depth++) {
		const node = await getNode(id);
		chain.unshift(node);
		id = node.parent;
	}
	return chain;
}

export function createFolder(parent: string, name: string) {
	return nodes().create({ owner: pb.authStore.record?.id, parent, name, kind: 'folder' });
}

export function renameNode(id: string, name: string) {
	return nodes().update(id, { name });
}

export function trashNode(id: string) {
	return nodes().update(id, { trashed_at: new Date().toISOString() });
}

/** Top-level trashed items (children of a trashed folder stay with it). */
export function listTrash() {
	return nodes().getFullList({ filter: 'trashed_at != ""', sort: '-trashed_at', batch: 500 });
}

/** Restores into the original folder, or the root if that folder is gone or trashed. */
export async function restoreNode(node: DriveNode) {
	let parent = node.parent;
	if (parent) {
		const original = await getNode(parent).catch(() => null);
		if (!original || original.trashed_at) parent = '';
	}
	return nodes().update(node.id, { trashed_at: '', parent });
}

export function deleteForever(id: string) {
	return nodes().delete(id);
}

/**
 * Downloads under the drive name (see /api/v1/nodes/{id}/download in the
 * OpenAPI spec), with a short-lived file token since the blob is protected.
 */
export async function downloadNode(node: DriveNode) {
	const token = await pb.files.getToken();
	const url = `/api/v1/nodes/${encodeURIComponent(node.id)}/download?token=${encodeURIComponent(token)}`;
	const a = document.createElement('a');
	a.href = url;
	a.rel = 'noopener';
	a.click();
}

export function moveNode(id: string, parent: string) {
	return nodes().update(id, { parent });
}

/** Folder children only, for the move picker. */
export function listFolders(parent: string) {
	return nodes().getFullList({
		filter: pb.filter('parent = {:parent} && kind = "folder" && trashed_at = ""', { parent }),
		batch: 500
	});
}

/**
 * Runs an operation on many ids with bounded concurrency; returns the ids
 * that failed (the caller reports them, successes arrive via live updates).
 */
export async function forEachNode(
	ids: string[],
	op: (id: string) => Promise<unknown>,
	concurrency = 4
): Promise<string[]> {
	const failed: string[] = [];
	const queue = [...ids];
	const worker = async () => {
		for (let id = queue.shift(); id !== undefined; id = queue.shift()) {
			await op(id).catch(() => failed.push(id));
		}
	};
	await Promise.all(Array.from({ length: Math.min(concurrency, ids.length) }, worker));
	return failed;
}
