import { createApiClient, type components, type paths } from '@alcove/api-spec';
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
	/** Restored from Google Photos (ADR 0030). */
	description?: string;
	thumb: string;
	preview: string;
	expand?: { node?: DriveNode };
}

export type PhotoFilter = 'all' | 'favorites' | 'videos';
export const PAGE_SIZE = 120;

/** Narrowing filters of the timeline (the panel next to All / Favorites / Videos). */
export interface Refine {
	year?: number;
	camera?: { make: string; model: string };
	located?: boolean;
}

export const isRefined = (r: Refine) => !!(r.year || r.camera || r.located);

/** The PocketBase filter for a timeline view. */
export function timelineFilter(filter: PhotoFilter, refine: Refine = {}) {
	const parts = ['node.trashed_at = ""'];
	if (filter === 'favorites') parts.push('favorite = true');
	if (filter === 'videos') parts.push('kind = "video"');
	if (refine.year) {
		parts.push(
			pb.filter('taken_at >= {:from} && taken_at < {:to}', {
				from: `${refine.year}-01-01 00:00:00.000Z`,
				to: `${refine.year + 1}-01-01 00:00:00.000Z`
			})
		);
	}
	if (refine.camera) {
		parts.push(
			pb.filter('camera_make = {:make} && camera_model = {:model}', {
				make: refine.camera.make,
				model: refine.camera.model
			})
		);
	}
	if (refine.located) parts.push('has_location = true');
	return parts.join(' && ');
}

/** One page of the timeline (newest first), trashed files excluded. */
export function listMedia(page: number, filter: PhotoFilter, refine: Refine = {}) {
	return pb.collection<Media>('media').getList(page, PAGE_SIZE, {
		filter: timelineFilter(filter, refine),
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

export type Facets =
	paths['/api/v1/photos/facets']['get']['responses']['200']['content']['application/json'];
export type DuplicateGroup = components['schemas']['DuplicateGroup'];
export type DuplicateItem = components['schemas']['DuplicateItem'];

const api = () => createApiClient(window.location.origin);
const auth = () => ({ Authorization: pb.authStore.token });

export async function getFacets(): Promise<Facets> {
	const { data, response } = await api().GET('/api/v1/photos/facets', { headers: auth() });
	if (!data) throw new Error(`facets failed: ${response.status}`);
	return data;
}

export async function listDuplicates(): Promise<DuplicateGroup[]> {
	const { data, response } = await api().GET('/api/v1/photos/duplicates', { headers: auth() });
	if (!data) throw new Error(`duplicates failed: ${response.status}`);
	return data.groups;
}

export async function dismissDuplicates(items: string[]) {
	const { response } = await api().POST('/api/v1/photos/duplicates/dismiss', {
		headers: auth(),
		body: { items }
	});
	if (!response.ok) throw new Error(`dismiss failed: ${response.status}`);
}

export type Location =
	paths['/api/v1/photos/locations']['get']['responses']['200']['content']['application/json']['items'][number];
export type MapConfig = components['schemas']['MapConfig'];

export async function listLocations() {
	const { data, response } = await api().GET('/api/v1/photos/locations', { headers: auth() });
	if (!data) throw new Error(`locations failed: ${response.status}`);
	return data;
}

export async function getMapConfig(): Promise<MapConfig> {
	const { data, response } = await api().GET('/api/v1/map/config', { headers: auth() });
	if (!data) throw new Error(`map config failed: ${response.status}`);
	return data;
}

export async function setMapTiles(osm: boolean): Promise<MapConfig> {
	const { data, response } = await api().PUT('/api/v1/admin/map', {
		headers: auth(),
		body: { osm }
	});
	if (!data) throw new Error(`map tiles failed: ${response.status}`);
	return data;
}

/** Full records (with file names) for the viewer, newest first. */
export function getMediaMany(ids: string[]) {
	return pb.collection<Media>('media').getFullList({
		filter: ids.map((id) => pb.filter('id = {:id}', { id })).join(' || '),
		expand: 'node',
		sort: '-taken_at,-id'
	});
}

export interface Memory {
	yearsAgo: number;
	year: number;
	items: Media[];
}

/** Photos taken around today in previous years, by year (most recent first). */
export async function getMemories(today = new Date()): Promise<Memory[]> {
	const date = [
		today.getFullYear(),
		String(today.getMonth() + 1).padStart(2, '0'),
		String(today.getDate()).padStart(2, '0')
	].join('-');
	const { data, response } = await api().GET('/api/v1/photos/memories', {
		headers: auth(),
		params: { query: { date } }
	});
	if (!data) throw new Error(`memories failed: ${response.status}`);
	return data.memories as unknown as Memory[];
}
