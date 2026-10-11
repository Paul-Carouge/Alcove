import { describe, expect, it } from 'vitest';
import { loadServerStatus } from './status';

const health = (api: { min: number; max: number }) => ({
	status: 'ok',
	name: 'Alcove',
	version: '0.1.0',
	api,
	modules: ['core'],
	setupRequired: false
});

const fakeFetch =
	(body: unknown, status = 200): typeof fetch =>
	async () =>
		new Response(JSON.stringify(body), {
			status,
			headers: { 'Content-Type': 'application/json' }
		});

describe('loadServerStatus', () => {
	it('reports a compatible server', async () => {
		const s = await loadServerStatus('http://x', fakeFetch(health({ min: 1, max: 1 })));
		expect(s.kind).toBe('connected');
	});

	it('detects a client that is too old', async () => {
		const s = await loadServerStatus('http://x', fakeFetch(health({ min: 2, max: 3 })));
		expect(s).toMatchObject({ kind: 'incompatible', reason: 'client-too-old' });
	});

	it('detects a server that is too old', async () => {
		const s = await loadServerStatus('http://x', fakeFetch(health({ min: 0, max: 0 })));
		expect(s).toMatchObject({ kind: 'incompatible', reason: 'server-too-old' });
	});

	it('rejects malformed payloads', async () => {
		const s = await loadServerStatus('http://x', fakeFetch({ hello: 'world' }));
		expect(s).toEqual({ kind: 'error', reason: 'invalid-response' });
	});

	it('reports network failures as unreachable', async () => {
		const failing: typeof fetch = async () => {
			throw new TypeError('network');
		};
		expect(await loadServerStatus('http://x', failing)).toEqual({
			kind: 'error',
			reason: 'unreachable'
		});
	});
});
