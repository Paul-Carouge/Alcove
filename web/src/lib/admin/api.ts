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
