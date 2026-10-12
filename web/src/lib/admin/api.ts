import { createApiClient, type components } from '@alcove/api-spec';
import { pb } from '#lib/pb.js';

export type SystemInfo = components['schemas']['SystemInfo'];

const api = () => createApiClient(window.location.origin);
const auth = () => ({ Authorization: pb.authStore.token });

export class AdminError extends Error {
	constructor(
		readonly status: number,
		message = ''
	) {
		super(message || `admin request failed: ${status}`);
	}
}

export async function getSystem(): Promise<SystemInfo> {
	const { data, response } = await api().GET('/api/v1/admin/system', { headers: auth() });
	if (!data) throw new AdminError(response.status);
	return data;
}

export async function checkUpdates(): Promise<SystemInfo> {
	const { data, response } = await api().POST('/api/v1/admin/updates/check', { headers: auth() });
	if (!data) throw new AdminError(response.status);
	return data;
}

export async function applyUpdate(): Promise<string> {
	const { data, response, error } = await api().POST('/api/v1/admin/updates/apply', {
		headers: auth()
	});
	if (!data) throw new AdminError(response.status, (error as { message?: string })?.message);
	return data.version;
}

/** Polls /health until the server reports `version` (after a restart). */
export async function waitForVersion(version: string, timeoutMs = 180_000): Promise<boolean> {
	const deadline = Date.now() + timeoutMs;
	while (Date.now() < deadline) {
		try {
			const res = await fetch('/health', { cache: 'no-store' });
			if (res.ok && (await res.json()).version === version) return true;
		} catch {
			// Restarting: connection refused for a few seconds.
		}
		await new Promise((r) => setTimeout(r, 2000));
	}
	return false;
}

// --- Accounts (admin) ---

export type AdminUser = components['schemas']['AdminUser'];

export interface AccountChanges {
	name?: string;
	quotaBytes?: number;
	admin?: boolean;
	password?: string;
}

async function fail(response: Response, error: unknown): Promise<never> {
	throw new AdminError(response.status, (error as { message?: string } | undefined)?.message ?? '');
}

export async function listUsers(): Promise<AdminUser[]> {
	const { data, response, error } = await api().GET('/api/v1/admin/users', { headers: auth() });
	if (!data) return fail(response, error);
	return data.items;
}

export async function createUser(
	body: AccountChanges & { email: string; password: string }
): Promise<AdminUser> {
	const { data, response, error } = await api().POST('/api/v1/admin/users', {
		headers: auth(),
		body
	});
	if (!data) return fail(response, error);
	return data;
}

export async function updateUser(id: string, body: AccountChanges): Promise<AdminUser> {
	const { data, response, error } = await api().PATCH('/api/v1/admin/users/{userId}', {
		headers: auth(),
		params: { path: { userId: id } },
		body
	});
	if (!data) return fail(response, error);
	return data;
}

export async function deleteUser(id: string) {
	const { response, error } = await api().DELETE('/api/v1/admin/users/{userId}', {
		headers: auth(),
		params: { path: { userId: id } }
	});
	if (!response.ok) await fail(response, error);
}

/** A random password that is easy to read aloud and type (no ambiguous characters). */
export function generatePassword(length = 16): string {
	const alphabet = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
	const bytes = crypto.getRandomValues(new Uint8Array(length));
	const chars = Array.from(bytes, (b) => alphabet[b % alphabet.length]);
	// Groups of four: "abcd-efgh-…"
	return chars.join('').replace(/(.{4})(?=.)/g, '$1-');
}

export const GB = 1_000_000_000;
