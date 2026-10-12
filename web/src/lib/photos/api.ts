import { createApiClient } from '@alcove/api-spec';
import type { RecordModel } from 'pocketbase';
import { contentUrl, fileToken } from '#lib/drive/files.js';
import type { DriveNode } from '#lib/drive/types.js';
import { pb } from '#lib/pb.js';

/** A record of the `media` collection (see server/migrations). */
export interface Media extends RecordModel {
	node: string;
	kind: 'image' | 'video';
	status: 'pending' | 'ready' | 'failed';
	taken_at: string;
	width: number;
	height: number;
	duration: number;
	camera_make: string;
	camera_model: string;
	lens: string;
	exposure: string;
	has_location: boolean;
	lat: number;
	lon: number;
	favorite: boolean;
	thumb: string;
	preview: string;
	expand?: { node?: DriveNode };
}

export type PhotoFilter = 'all' | 'favorites' | 'videos';
export const PAGE_SIZE = 120;

/** One page of the timeline (newest first), trashed files excluded. */
export function listMedia(page: number, filter: PhotoFilter) {
	const parts = ['node.trashed_at = ""'];
	if (filter === 'favorites') parts.push('favorite = true');
	if (filter === 'videos') parts.push('kind = "video"');
	return pb.collection<Media>('media').getList(page, PAGE_SIZE, {
		filter: parts.join(' && '),
		sort: '-taken_at,-id',
		expand: 'node'
	});
}

export function getMedia(id: string) {
	return pb.collection<Media>('media').getOne(id, { expand: 'node' });
}

export async function setFavorite(id: string, favorite: boolean) {
	const { response } = await createApiClient(window.location.origin).PUT(
		'/api/v1/media/{mediaId}/favorite',
		{
			params: { path: { mediaId: id } },
			headers: { Authorization: pb.authStore.token },
			body: { favorite }
		}
	);
	if (!response.ok) throw new Error(`favorite failed: ${response.status}`);
}

const NATIVE = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
const baseMime = (m = '') => m.split(';')[0]!.trim();

/** Grid thumbnail: generated JPEG, or a PocketBase thumbnail of the original. */
export function thumbUrl(m: Media, token: string): string | null {
	if (m.thumb) return pb.files.getURL(m, m.thumb, { token });
	const node = m.expand?.node;
	if (node?.blob && NATIVE.includes(baseMime(node.mime))) {
		return pb.files.getURL(node, node.blob, { thumb: '0x360', token });
	}
	return null;
}

/** Large image for the viewer. */
export function previewUrl(m: Media, token: string): string | null {
	if (m.preview) return pb.files.getURL(m, m.preview, { token });
	const node = m.expand?.node;
	if (!node?.blob) return null;
	const mime = baseMime(node.mime);
	if (mime === 'image/gif') return contentUrl(node, token);
	if (NATIVE.includes(mime)) return pb.files.getURL(node, node.blob, { thumb: '1600x0', token });
	return null;
}

/** The original file, for its owner and the people of albums it is in (ADR 0018). */
export const originalUrl = (m: Pick<Media, 'id'>, token: string, inline = true) =>
	`/api/v1/media/${encodeURIComponent(m.id)}/original?token=${encodeURIComponent(token)}${inline ? '&inline=1' : ''}`;

export const videoUrl = (m: Media, token: string) => originalUrl(m, token);

export async function downloadMedia(m: Pick<Media, 'id'>) {
	const a = document.createElement('a');
	a.href = originalUrl(m, await fileToken(), false);
	a.rel = 'noopener';
	a.click();
}

export { fileToken };

/** "YYYY-MM" in local time, for grouping by month. */
export function monthKey(iso: string) {
	const d = new Date(iso.replace(' ', 'T'));
	return Number.isNaN(d.getTime())
		? '0000-00'
		: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

export function monthLabel(key: string, locale: string) {
	const [y, m] = key.split('-').map(Number);
	if (!y) return '';
	const label = new Intl.DateTimeFormat(locale, { month: 'long', year: 'numeric' }).format(
		new Date(y, m! - 1, 1)
	);
	return label.charAt(0).toUpperCase() + label.slice(1);
}

export function formatDuration(seconds: number) {
	const s = Math.round(seconds);
	const h = Math.floor(s / 3600);
	const mm = Math.floor((s % 3600) / 60);
	const ss = String(s % 60).padStart(2, '0');
	return h ? `${h}:${String(mm).padStart(2, '0')}:${ss}` : `${mm}:${ss}`;
}
