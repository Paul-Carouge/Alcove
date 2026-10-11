import { describe, expect, it } from 'vitest';
import { hasThumbnail, previewKind } from './files';

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
