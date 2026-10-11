import { describe, expect, it } from 'vitest';
import { forEachNode } from './api';
import { Selection } from './selection.svelte';

const order = ['a', 'b', 'c', 'd', 'e'];

describe('Selection', () => {
	it('toggles and selects shift ranges in both directions', () => {
		const s = new Selection();
		s.toggle('b', order);
		s.toggle('d', order, true);
		expect([...s.ids].sort()).toEqual(['b', 'c', 'd']);
		s.toggle('a', order, true);
		expect([...s.ids].sort()).toEqual(['a', 'b', 'c', 'd']);
		s.toggle('c', order);
		expect(s.has('c')).toBe(false);
	});

	it('select all, retain visible, clear', () => {
		const s = new Selection();
		s.setAll(order, true);
		expect(s.size).toBe(5);
		s.retain(['a', 'e']);
		expect([...s.ids]).toEqual(['a', 'e']);
		s.clear();
		expect(s.size).toBe(0);
	});
});

describe('forEachNode', () => {
	it('returns the ids that failed and respects the concurrency limit', async () => {
		let running = 0;
		let peak = 0;
		const failed = await forEachNode(
			['1', '2', '3', '4', '5', '6'],
			async (id) => {
				running++;
				peak = Math.max(peak, running);
				await new Promise((r) => setTimeout(r, 5));
				running--;
				if (id === '2' || id === '5') throw new Error('nope');
			},
			2
		);
		expect(failed.sort()).toEqual(['2', '5']);
		expect(peak).toBeLessThanOrEqual(2);
	});
});
