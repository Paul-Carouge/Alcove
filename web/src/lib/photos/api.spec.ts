import { describe, expect, it } from 'vitest';
import { formatDuration, monthKey, monthLabel } from './api';

describe('photo helpers', () => {
	it('groups by local month', () => {
		expect(monthKey('2025-06-01 12:00:00.000Z')).toMatch(/^2025-0[56]$/);
		expect(monthKey('garbage')).toBe('0000-00');
	});
	it('labels months with a capital letter', () => {
		expect(monthLabel('2025-06', 'fr')).toBe('Juin 2025');
		expect(monthLabel('2024-12', 'en')).toBe('December 2024');
	});
	it('formats durations', () => {
		expect(formatDuration(3)).toBe('0:03');
		expect(formatDuration(75.4)).toBe('1:15');
		expect(formatDuration(3725)).toBe('1:02:05');
	});
});
