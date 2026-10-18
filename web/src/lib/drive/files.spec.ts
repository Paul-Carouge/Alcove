import { describe, expect, it, vi } from 'vitest';
import { hasThumbnail, isMedia, mediaOf, prefersMedia, previewKind } from './files';
import type { DriveNode } from './types';

const file = (mime: string) => ({ kind: 'file' as const, mime });

describe('previewKind', () => {
	it.each([
		['image/png', 'image'],
		['video/mp4', 'video'],
		['audio/mpeg', 'audio'],
		['application/pdf', 'pdf'],
		['text/plain; charset=utf-8', 'text'],
		['text/html; charset=utf-8', null],
		['image/svg+xml', null],
		['application/zip', null]
	])('%s -> %s', (mime, kind) => expect(previewKind(file(mime))).toBe(kind));

	it('never previews folders', () => {
		expect(previewKind({ kind: 'folder', mime: '' })).toBeNull();
	});
});

describe('hasThumbnail', () => {
	it('only for formats PocketBase can thumbnail', () => {
		expect(hasThumbnail(file('image/jpeg'))).toBe(true);
		expect(hasThumbnail(file('image/avif'))).toBe(false);
		expect(hasThumbnail(file('image/svg+xml'))).toBe(false);
	});
});

describe('prefersMedia', () => {
	it('generated JPEGs for HEIC, videos and JPEG; PocketBase for PNG, GIF, WebP', () => {
		expect(prefersMedia(file('image/heic'))).toBe(true);
		expect(prefersMedia(file('video/quicktime'))).toBe(true);
		expect(prefersMedia(file('image/jpeg'))).toBe(true);
		expect(prefersMedia(file('image/png'))).toBe(false);
		expect(prefersMedia(file('image/gif'))).toBe(false);
	});
});

describe('isMedia', () => {
	it('photos and videos except SVG', () => {
		expect(isMedia(file('image/heic'))).toBe(true);
		expect(isMedia(file('video/quicktime'))).toBe(true);
		expect(isMedia(file('image/svg+xml'))).toBe(false);
		expect(isMedia({ kind: 'folder', mime: '' })).toBe(false);
	});
});

const getFullList = vi.fn();
vi.mock('#lib/pb.js', () => ({
	pb: {
		filter: (expr: string, p: { id: string }) => expr.replace('{:id}', JSON.stringify(p.id)),
		collection: () => ({ getFullList })
	}
}));

describe('mediaOf', () => {
	const node = (id: string, mime = 'image/heic') =>
		({ id, kind: 'file', mime, blob: `${id}.heic` }) as DriveNode;

	it('batches lookups of one tick and caches ready items', async () => {
		getFullList.mockResolvedValueOnce([
			{ id: 'm1', node: 'a', thumb: 't.jpg', preview: 'p.jpg' },
			{ id: 'm2', node: 'b', thumb: '', preview: '' } // still pending
		]);
		const [a, b, doc] = await Promise.all([
			mediaOf(node('a')),
			mediaOf(node('b')),
			mediaOf(node('c', 'application/pdf'))
		]);
		expect(getFullList).toHaveBeenCalledTimes(1);
		expect(getFullList.mock.calls[0]![0].filter).toBe('node = "a" || node = "b"');
		expect(a?.id).toBe('m1');
		expect(b).toBeNull();
		expect(doc).toBeNull();

		expect((await mediaOf(node('a')))?.id).toBe('m1');
		expect(getFullList).toHaveBeenCalledTimes(1);
	});
});
