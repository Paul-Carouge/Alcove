import { describe, expect, it } from 'vitest';
import { expiryFromPreset, publicFileUrl } from './api';

describe('expiryFromPreset', () => {
	const now = new Date('2026-10-11T12:00:00.123Z');
	it('maps presets to RFC 3339 dates', () => {
		expect(expiryFromPreset('never', now)).toBeUndefined();
		expect(expiryFromPreset('1d', now)).toBe('2026-10-12T12:00:00Z');
		expect(expiryFromPreset('30d', now)).toBe('2026-11-10T12:00:00Z');
	});
});

describe('publicFileUrl', () => {
	it('encodes and only adds the parameters that are set', () => {
		expect(publicFileUrl('t/ok', 'n1')).toBe('/api/v1/public/shares/t%2Fok/files/n1');
		expect(publicFileUrl('t', 'n1', 'acc', true)).toBe(
			'/api/v1/public/shares/t/files/n1?access=acc&inline=1'
		);
	});
});
