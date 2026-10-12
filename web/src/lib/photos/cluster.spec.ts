import { describe, expect, it } from 'vitest';
import { cluster } from './cluster';

describe('cluster', () => {
	it('groups points falling in the same cell and keeps order', () => {
		const out = cluster(
			[
				{ x: 10, y: 10, item: 'a' },
				{ x: 50, y: 20, item: 'b' },
				{ x: 200, y: 10, item: 'c' }
			],
			64
		);
		expect(out).toHaveLength(2);
		expect(out[0]).toEqual({ x: 30, y: 15, items: ['a', 'b'] });
		expect(out[1]!.items).toEqual(['c']);
	});
	it('handles no points', () => {
		expect(cluster([], 64)).toEqual([]);
	});
});
