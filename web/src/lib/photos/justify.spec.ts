import { describe, expect, it } from 'vitest';
import { clampRatio, justify } from './justify';

const r = (x: number) => x;

describe('justify', () => {
	it('fills each full row to the exact width', () => {
		const rows = justify([1.5, 1.5, 1.5, 1, 1, 0.75, 1.5], r, 1000, 300, 4);
		for (const row of rows.slice(0, -1)) {
			const total =
				row.items.reduce((s, x) => s + clampRatio(x) * row.height, 0) + 4 * (row.items.length - 1);
			expect(total).toBeCloseTo(1000, 5);
			expect(row.height).toBeLessThanOrEqual(300);
		}
	});

	it('does not stretch the last row beyond the target', () => {
		const rows = justify([1.5], r, 1000, 300, 4);
		expect(rows).toHaveLength(1);
		expect(rows[0]!.height).toBe(300);
	});

	it('clamps extreme ratios and handles empty input or zero width', () => {
		expect(clampRatio(10)).toBe(3);
		expect(clampRatio(0)).toBe(1);
		expect(justify([], r, 1000, 300, 4)).toEqual([]);
		expect(justify([1], r, 0, 300, 4)).toEqual([]);
	});
});
