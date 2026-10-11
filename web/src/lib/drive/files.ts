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

export function contentUrl(node: DriveNode, token: string, inline = true) {
	const q = new URLSearchParams({ token, ...(inline ? { inline: '1' } : {}) });
	return `/api/v1/nodes/${encodeURIComponent(node.id)}/download?${q}`;
}
