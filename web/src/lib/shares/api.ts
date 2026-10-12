import { createApiClient, type components } from '@alcove/api-spec';
import type { RecordModel } from 'pocketbase';
import type { DriveNode } from '#lib/drive/types.js';
import { pb } from '#lib/pb.js';

export type PublicShare = components['schemas']['PublicShare'];
export type PublicNode = components['schemas']['PublicNode'];
export type PublicMedia = components['schemas']['PublicMedia'];

/** What a link points to: a drive node or an album. */
export interface ShareTarget {
	id: string;
	name: string;
	album?: boolean;
}

export interface ShareRecord extends RecordModel {
	node: string;
	album: string;
	created_by: string;
	has_password: boolean;
	expires_at: string;
	created: string;
	expand?: { node?: DriveNode; album?: RecordModel & { name: string } };
}

const api = () => createApiClient(window.location.origin);

export class ShareError extends Error {
	constructor(
		readonly status: number,
		readonly requiresPassword = false
	) {
		super(`share request failed: ${status}`);
	}
}

/** Creates a link; the token comes back only in this response. */
export async function createShare(
	target: ShareTarget,
	opts: { expiresAt?: string; password?: string }
) {
	const { data, response } = await api().POST('/api/v1/shares', {
		headers: { Authorization: pb.authStore.token },
		body: { ...(target.album ? { album: target.id } : { node: target.id }), ...opts }
	});
	if (!data) throw new ShareError(response.status);
	return data;
}

export const shareUrl = (token: string) =>
	`${window.location.origin}/s/${encodeURIComponent(token)}`;

export function sharesFor(target: ShareTarget) {
	return pb.collection<ShareRecord>('shares').getFullList({
		filter: target.album
			? pb.filter('album = {:id}', { id: target.id })
			: pb.filter('node = {:id}', { id: target.id }),
		sort: '-created'
	});
}

export function myShares() {
	return pb
		.collection<ShareRecord>('shares')
		.getFullList({ sort: '-created', expand: 'node,album' });
}

export function revokeShare(id: string) {
	return pb.collection('shares').delete(id);
}

// --- Public (no account) ---

export async function getPublicShare(token: string, access?: string, folder?: string) {
	const { data, response, error } = await api().GET('/api/v1/public/shares/{token}', {
		params: { path: { token }, query: { access, folder } }
	});
	if (!data) {
		const requires = (error as { data?: { requiresPassword?: boolean } } | undefined)?.data
			?.requiresPassword;
		throw new ShareError(response.status, requires === true);
	}
	return data;
}

export async function unlockShare(token: string, password: string) {
	const { data, response } = await api().POST('/api/v1/public/shares/{token}/unlock', {
		params: { path: { token } },
		body: { password }
	});
	if (!data) throw new ShareError(response.status);
	return data;
}

export function publicFileUrl(token: string, nodeId: string, access?: string, inline = false) {
	const q = new URLSearchParams({
		...(access ? { access } : {}),
		...(inline ? { inline: '1' } : {})
	});
	const qs = q.toString();
	return `/api/v1/public/shares/${encodeURIComponent(token)}/files/${encodeURIComponent(nodeId)}${qs ? `?${qs}` : ''}`;
}

/** Expiry presets offered in the share dialog. */
export function expiryFromPreset(
	preset: 'never' | '1d' | '7d' | '30d',
	now = new Date()
): string | undefined {
	const days = { never: 0, '1d': 1, '7d': 7, '30d': 30 }[preset];
	return days
		? new Date(now.getTime() + days * 86_400_000).toISOString().replace(/\.\d{3}Z$/, 'Z')
		: undefined;
}

/** An image or video of a shared album (photos: generated JPEGs only). */
export function publicMediaUrl(
	token: string,
	mediaId: string,
	variant: 'thumb' | 'preview' | 'video',
	access?: string
) {
	const qs = access ? `?access=${encodeURIComponent(access)}` : '';
	return `/api/v1/public/shares/${encodeURIComponent(token)}/media/${encodeURIComponent(mediaId)}/${variant}${qs}`;
}
