import { describe, expect, it } from 'vitest';
import { formatDate, formatSize } from './format';
import { compareNodes, isValidName } from './names';

describe('isValidName', () => {
	it.each([
		['report.pdf', true],
		['.bashrc', true],
		['a/b', false],
		['..', false],
		['.', false],
		['', false],
		['tab\there', false],
		['x'.repeat(256), false]
	])('%s -> %s', (name, ok) => expect(isValidName(name)).toBe(ok));
});

describe('compareNodes', () => {
	it('puts folders first and sorts naturally', () => {
		const items = [
			{ kind: 'file', name: 'b10.txt' },
			{ kind: 'file', name: 'B2.txt' },
			{ kind: 'folder', name: 'zeta' },
			{ kind: 'file', name: 'a.txt' }
		];
		expect(items.sort((a, b) => compareNodes(a, b, 'en')).map((i) => i.name)).toEqual([
			'zeta',
			'a.txt',
			'B2.txt',
			'b10.txt'
		]);
	});
});

describe('formatSize', () => {
	it('formats with locale units', () => {
		expect(formatSize(0, 'en')).toBe('0\u00a0B');
		expect(formatSize(6, 'fr')).toBe('6\u00a0o');
		expect(formatSize(999, 'en')).toBe('999\u00a0B');
		expect(formatSize(1500, 'en')).toBe('1.5 kB');
		expect(formatSize(1_234_567, 'fr')).toMatch(/^1,2\sMo$/);
	});
});

describe('formatDate', () => {
	const now = new Date('2026-10-11T15:00:00');
	it('shows the time for today and a date otherwise', () => {
		expect(formatDate('2026-10-11 09:05:00.000Z', 'en', now)).toMatch(/\d{2}:\d{2}/);
		expect(formatDate('2026-03-02 09:05:00.000Z', 'en', now)).toBe('Mar 2');
		expect(formatDate('2025-03-02 09:05:00.000Z', 'en', now)).toBe('Mar 2, 2025');
	});
});
