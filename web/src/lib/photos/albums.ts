import { createApiClient, type components } from '@alcove/api-spec';
import type { RecordModel } from 'pocketbase';
import { pb } from '#lib/pb.js';
import type { Media } from './api.js';

export type AlbumSummary = components['schemas']['AlbumSummary'];
export type AlbumItem = components['schemas']['AlbumItem'];
export type Person = components['schemas']['Person'];
export type Role = 'viewer' | 'contributor';
export interface Participant extends Person {
	role: Role;
}

/** A record of the `albums` collection. */
export interface AlbumRecord extends RecordModel {
	owner: string;
	name: string;
	cover: string;
	members: string[];
	contributors: string[];
}

const api = () => createApiClient(window.location.origin);
const auth = () => ({ Authorization: pb.authStore.token });
const albums = () => pb.collection<AlbumRecord>('albums');
const me = () => pb.authStore.record?.id ?? '';

function check(response: Response) {
	if (!response.ok) throw new Error(`HTTP ${response.status}`);
}

export async function listAlbums(): Promise<AlbumSummary[]> {
	const { data, response } = await api().GET('/api/v1/albums', { headers: auth() });
	check(response);
	return data!.items;
}

export const getAlbum = (id: string) => albums().getOne(id);

export const createAlbum = (name: string) => albums().create({ owner: me(), name });
export const renameAlbum = (id: string, name: string) => albums().update(id, { name });
export const setCover = (id: string, mediaId: string) => albums().update(id, { cover: mediaId });
export const deleteAlbum = (id: string) => albums().delete(id);

/** Saves who the album is shared with, and how. */
export function shareAlbum(id: string, people: Pick<Participant, 'id' | 'role'>[]) {
	return albums().update(id, splitRoles(people));
}

export function splitRoles(people: Pick<Participant, 'id' | 'role'>[]) {
	return {
		members: people.filter((p) => p.role === 'viewer').map((p) => p.id),
		contributors: people.filter((p) => p.role === 'contributor').map((p) => p.id)
	};
}

export async function listAlbumItems(id: string, page: number, perPage = 200) {
	const { data, response } = await api().GET('/api/v1/albums/{albumId}/items', {
		params: { path: { albumId: id }, query: { page, perPage } },
		headers: auth()
	});
	check(response);
	return data!;
}

export async function getPeople(id: string) {
	const { data, response } = await api().GET('/api/v1/albums/{albumId}/people', {
		params: { path: { albumId: id } },
		headers: auth()
	});
	check(response);
	return data as { owner: Person; people: Participant[] };
}

export async function leaveAlbum(id: string) {
	const { response } = await api().POST('/api/v1/albums/{albumId}/leave', {
		params: { path: { albumId: id } },
		headers: auth()
	});
	check(response);
}

/** The account with this email, or null when there is none. */
export async function lookupUser(email: string): Promise<Person | null> {
	const { data, response } = await api().GET('/api/v1/users/lookup', {
		params: { query: { email } },
		headers: auth()
	});
	if (response.status === 404) return null;
	check(response);
	return data!;
}

/** Adds photos (your own) to an album; ones already in it are skipped. Returns how many were added. */
export async function addToAlbum(albumId: string, mediaIds: string[]): Promise<number> {
	let added = 0;
	for (let i = 0; i < mediaIds.length; i += 6) {
		const batch = mediaIds.slice(i, i + 6);
		const results = await Promise.allSettled(
			batch.map((media) =>
				pb
					.collection('album_items')
					.create({ album: albumId, media, added_by: me() }, { requestKey: null })
			)
		);
		added += results.filter((r) => r.status === 'fulfilled').length;
	}
	return added;
}

export const removeItem = (itemId: string) => pb.collection('album_items').delete(itemId);

/** Album items in the shape the photo grid and viewer use. */
export type AlbumMedia = Media & { itemId: string; addedBy: string };

export function toMedia(it: AlbumItem): AlbumMedia {
	return {
		...it,
		collectionName: 'media',
		node: '',
		expand: { node: { name: it.name, size: it.size, mime: it.mime } }
	} as unknown as AlbumMedia;
}

/** Albums you can add photos to. */
export const canAddTo = (a: Pick<AlbumSummary, 'role'>) => a.role !== 'viewer';

/** Whether you may take an item out of an album: the album's owner, or whoever added it. */
export const canRemove = (role: AlbumSummary['role'], item: Pick<AlbumItem, 'addedBy'>) =>
	role === 'owner' || item.addedBy === me();
