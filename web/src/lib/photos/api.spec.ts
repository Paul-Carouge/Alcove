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

import { isRefined, timelineFilter } from './api';

describe('timeline filters', () => {
	it('builds the PocketBase filter', () => {
		expect(timelineFilter('all')).toBe('node.trashed_at = ""');
		const f = timelineFilter('videos', {
			year: 2025,
			camera: { make: 'Apple', model: 'iPhone "16"' },
			located: true
		});
		expect(f).toContain('kind = "video"');
		expect(f).toContain(
			'taken_at >= "2025-01-01 00:00:00.000Z" && taken_at < "2026-01-01 00:00:00.000Z"'
		);
		// Values are quoted and escaped by the SDK (no filter injection).
		expect(f).toContain('camera_model = "iPhone \\"16\\""');
		expect(f).toContain('has_location = true');
	});
	it('knows when the timeline is narrowed', () => {
		expect(isRefined({})).toBe(false);
		expect(isRefined({ located: true })).toBe(true);
	});
});
