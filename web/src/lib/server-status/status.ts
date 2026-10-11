import { checkCompatibility, createApiClient, type Health } from '@alcove/api-spec';

export type ServerStatus =
	| { kind: 'connected'; health: Health }
	| { kind: 'incompatible'; health: Health; reason: 'client-too-old' | 'server-too-old' }
	| { kind: 'error'; reason: 'unreachable' | 'invalid-response' };

function isHealth(value: unknown): value is Health {
	const h = value as Health;
	return (
		typeof h === 'object' &&
		h !== null &&
		h.status === 'ok' &&
		typeof h.version === 'string' &&
		Number.isInteger(h.api?.min) &&
		Number.isInteger(h.api?.max) &&
		Array.isArray(h.modules)
	);
}

/** Calls GET /health on baseUrl and checks API compatibility. Never throws. */
export async function loadServerStatus(
	baseUrl: string,
	fetchImpl: typeof fetch = fetch
): Promise<ServerStatus> {
	const client = createApiClient(baseUrl, fetchImpl);
	let data: unknown;
	try {
		const res = await client.GET('/health', { signal: AbortSignal.timeout(10_000) });
		if (!res.response.ok) return { kind: 'error', reason: 'invalid-response' };
		data = res.data;
	} catch {
		return { kind: 'error', reason: 'unreachable' };
	}
	if (!isHealth(data)) return { kind: 'error', reason: 'invalid-response' };

	const compat = checkCompatibility(data.api);
	return compat === 'ok'
		? { kind: 'connected', health: data }
		: { kind: 'incompatible', health: data, reason: compat };
}
