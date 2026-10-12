import { describe, expect, it } from 'vitest';
import { canAddTo, splitRoles, toMedia } from './albums';

describe('albums', () => {
	it('splits people into the two role lists', () => {
		expect(
			splitRoles([
				{ id: 'a', role: 'viewer' },
				{ id: 'b', role: 'contributor' },
				{ id: 'c', role: 'viewer' }
			])
		).toEqual({ members: ['a', 'c'], contributors: ['b'] });
	});
	it('only owners and contributors add photos', () => {
		expect(canAddTo({ role: 'owner' })).toBe(true);
		expect(canAddTo({ role: 'contributor' })).toBe(true);
		expect(canAddTo({ role: 'viewer' })).toBe(false);
	});
	it('shapes album items like media records', () => {
		const m = toMedia({
			id: 'm1',
			collectionId: 'c1',
			thumb: 't.jpg',
			preview: 'p.jpg',
			itemId: 'i1',
			addedBy: 'u1',
			kind: 'image',
			status: 'ready',
			taken_at: '2025-01-01 00:00:00.000Z',
			width: 4,
			height: 3,
			duration: 0,
			favorite: false,
			name: 'a.jpg',
			size: 10,
			mime: 'image/jpeg'
		});
		expect(m.expand?.node?.name).toBe('a.jpg');
		expect(m.itemId).toBe('i1');
		expect(m.collectionId).toBe('c1');
	});
});
