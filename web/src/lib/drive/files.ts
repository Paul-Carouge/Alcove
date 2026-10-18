import type { RecordModel } from 'pocketbase';
import { pb } from '#lib/pb.js';
import type { DriveNode } from './types.js';

// PocketBase file tokens live ~3 minutes; reuse one for a while so lists of
// thumbnails don't each request a token.
const TOKEN_REUSE_MS = 90_000;
let cached: { token: string; at: number; owner: string } | null = null;
let inflight: Promise<string> | null = null;

export async function fileToken(): Promise<string> {
	const owner = pb.authStore.record?.id ?? '';
	if (cached && cached.owner === owner && Date.now() - cached.at < TOKEN_REUSE_MS)
		return cached.token;
	inflight ??= pb.files
		.getToken()
		.then((token) => {
			cached = { token, at: Date.now(), owner };
			return token;
		})
		.finally(() => (inflight = null));
	return inflight;
}

export type PreviewKind = 'image' | 'video' | 'audio' | 'text' | 'pdf';

const base = (mime: string) => mime.split(';')[0]!.trim();

/** What the viewer can show; mirrors the server's inline allowlist. */
export function previewKind(node: Pick<DriveNode, 'kind' | 'mime'>): PreviewKind | null {
	if (node.kind !== 'file') return null;
	const m = base(node.mime);
	if (['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/avif'].includes(m))
		return 'image';
	if (['video/mp4', 'video/webm'].includes(m)) return 'video';
	if (m.startsWith('audio/')) return 'audio';
	if (m === 'application/pdf') return 'pdf';
	if (m === 'text/plain') return 'text';
	return null;
}

/** PocketBase can thumbnail these formats. */
export const hasThumbnail = (node: Pick<DriveNode, 'kind' | 'mime'>) =>
	node.kind === 'file' &&
	['image/jpeg', 'image/png', 'image/gif', 'image/webp'].includes(base(node.mime));

export type ThumbSize = '96x96' | '320x320' | '1600x0';

export function thumbUrl(node: DriveNode, size: ThumbSize, token: string) {
	return pb.files.getURL(node, node.blob, { thumb: size, token });
}

/** The server-generated derivatives of a photo or video (fields of the `media` collection). */
export type MediaFiles = Pick<RecordModel, 'id' | 'collectionId' | 'collectionName'> & {
	node: string;
	thumb: string;
	preview: string;
};

/** Photos and videos, which the media worker gives a thumbnail and a preview. */
export const isMedia = (node: Pick<DriveNode, 'kind' | 'mime'>) =>
	node.kind === 'file' &&
	/^(image|video)\//.test(base(node.mime)) &&
	base(node.mime) !== 'image/svg+xml';

// Keyed by node id and blob: new content gets new derivatives.
const mediaCache = new Map<string, MediaFiles | null>();
let pending = new Map<string, ((m: MediaFiles | null) => void)[]>();
let flushTimer: ReturnType<typeof setTimeout> | null = null;
const MEDIA_BATCH = 50;

async function flushMedia() {
	const wanted = pending;
	pending = new Map();
	flushTimer = null;
	const ids = [...wanted.keys()];
	for (let i = 0; i < ids.length; i += MEDIA_BATCH) {
		const chunk = ids.slice(i, i + MEDIA_BATCH);
		const filter = chunk.map((id) => pb.filter('node = {:id}', { id })).join(' || ');
		const found = await pb
			.collection<MediaFiles>('media')
			.getFullList({ filter, fields: 'id,collectionId,collectionName,node,thumb,preview' })
			.catch(() => [] as MediaFiles[]);
		const byNode = new Map(found.map((m) => [m.node, m]));
		for (const id of chunk) {
			const m = byNode.get(id);
			for (const resolve of wanted.get(id) ?? []) resolve(m?.thumb ? m : null);
		}
	}
}

/**
 * The thumbnail and preview the media worker made for a drive photo or video (HEIC, videos and
 * EXIF orientation included), or null while they are not ready. Lookups of one tick share requests.
 */
export function mediaOf(node: DriveNode): Promise<MediaFiles | null> {
	if (!isMedia(node) || !node.blob) return Promise.resolve(null);
	const key = `${node.id}:${node.blob}`;
	if (mediaCache.has(key)) return Promise.resolve(mediaCache.get(key)!);
	return new Promise((resolve) => {
		const list = pending.get(node.id) ?? [];
		list.push((m) => {
			if (m) mediaCache.set(key, m); // not ready yet: ask again next time
			resolve(m);
		});
		pending.set(node.id, list);
		flushTimer ??= setTimeout(flushMedia, 0);
	});
}

/**
 * Whether to show the media worker's JPEGs rather than a PocketBase thumbnail: for formats PocketBase
 * cannot read (HEIC, videos) and JPEGs (upright from EXIF). PNG, GIF and WebP keep transparency and motion.
 */
export const prefersMedia = (node: Pick<DriveNode, 'kind' | 'mime'>) =>
	isMedia(node) && (!hasThumbnail(node) || base(node.mime) === 'image/jpeg');

export const mediaUrl = (m: MediaFiles, file: 'thumb' | 'preview', token: string) =>
	pb.files.getURL(m, m[file], { token });

export function contentUrl(node: DriveNode, token: string, inline = true) {
	const q = new URLSearchParams({ token, ...(inline ? { inline: '1' } : {}) });
	return `/api/v1/nodes/${encodeURIComponent(node.id)}/download?${q}`;
}
