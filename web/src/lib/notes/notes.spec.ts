import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { renderMarkdown } from './markdown';
import { Autosave, excerpt, filterNotes, sortNotes, type NoteChanges } from './notes.svelte';

describe('sortNotes', () => {
	it('puts pinned notes first, then the most recent', () => {
		const notes = [
			{ id: 'a', pinned: false, updated: '2026-10-01 10:00:00.000Z' },
			{ id: 'b', pinned: true, updated: '2026-09-01 10:00:00.000Z' },
			{ id: 'c', pinned: false, updated: '2026-10-02 10:00:00.000Z' }
		];
		expect(sortNotes(notes).map((n) => n.id)).toEqual(['b', 'c', 'a']);
	});
});

describe('filterNotes', () => {
	const notes = [
		{ id: '1', title: 'Courses', body: 'Lait, œufs, café', tags: ['home'] },
		{ id: '2', title: 'Ideas', body: 'A café in Lyon', tags: [] }
	];
	it('matches every word in title or text, ignoring accents and case', () => {
		expect(filterNotes(notes, 'CAFE').map((n) => n.id)).toEqual(['1', '2']);
		expect(filterNotes(notes, 'cafe lyon').map((n) => n.id)).toEqual(['2']);
		expect(filterNotes(notes, 'courses').map((n) => n.id)).toEqual(['1']);
	});
	it('filters by tag', () => {
		expect(filterNotes(notes, '', 'home').map((n) => n.id)).toEqual(['1']);
	});
});

describe('excerpt', () => {
	it('returns the first line of text without Markdown markers', () => {
		expect(excerpt('\n# Title\nbody')).toBe('Title');
		expect(excerpt('---\n- [x] **Buy** [milk](https://x.y)')).toBe('Buy milk');
		expect(excerpt('')).toBe('');
		expect(excerpt('a'.repeat(200), 10)).toBe('aaaaaaaaa…');
	});
});

describe('renderMarkdown', () => {
	it('renders headings, lists, tasks, quotes and code', () => {
		expect(renderMarkdown('# Title\n- one\n- [x] done\n1. first\n> quoted')).toBe(
			'<h2>Title</h2><ul><li>one</li><li class="task done"><input type="checkbox" disabled checked> done</li></ul><ol><li>first</li></ol><blockquote>quoted</blockquote>'
		);
		expect(renderMarkdown('```\n<b>x</b>\n```')).toBe(
			'<pre><code>&lt;b&gt;x&lt;/b&gt;</code></pre>'
		);
	});

	it('joins lines of a paragraph and formats inline text', () => {
		expect(renderMarkdown('**bold** *it* `co*de*`\nnext')).toBe(
			'<p><strong>bold</strong> <em>it</em> <code>co*de*</code><br>next</p>'
		);
	});

	it('only links http(s) URLs, untouched by emphasis', () => {
		expect(renderMarkdown('[a](https://x.y/a_b_c)')).toBe(
			'<p><a href="https://x.y/a_b_c" target="_blank" rel="noopener noreferrer">a</a></p>'
		);
		expect(renderMarkdown('[a](javascript:alert(1))')).not.toContain('<a');
	});

	it('escapes HTML', () => {
		const html = renderMarkdown('<img src=x onerror=alert(1)>\n[x](https://a.b/"onmouseover=1)');
		expect(html).not.toMatch(/<img|"onmouseover/);
	});

	it('ignores typed placeholder characters', () => {
		expect(renderMarkdown('[a](https://x.y) \uE0000\uE000')).toBe(
			'<p><a href="https://x.y" target="_blank" rel="noopener noreferrer">a</a> 0</p>'
		);
	});
});

describe('Autosave', () => {
	beforeEach(() => vi.useFakeTimers());
	afterEach(() => vi.useRealTimers());

	it('saves once after a pause, merging changes', async () => {
		const save = vi.fn<(c: NoteChanges) => Promise<void>>().mockResolvedValue();
		const a = new Autosave(save, 500);
		a.change({ title: 'T' });
		a.change({ body: 'b' });
		expect(a.state).toBe('pending');
		await vi.advanceTimersByTimeAsync(500);
		expect(save).toHaveBeenCalledExactlyOnceWith({ title: 'T', body: 'b' });
		expect(a.state).toBe('saved');
		expect(a.dirty).toBe(false);
	});

	it('sends edits made during a save right after it, never in parallel', async () => {
		let release!: () => void;
		const save = vi
			.fn<(c: NoteChanges) => Promise<void>>()
			.mockImplementationOnce(() => new Promise((r) => (release = r)))
			.mockResolvedValue();
		const a = new Autosave(save, 100);
		a.change({ body: 'one' });
		await vi.advanceTimersByTimeAsync(100);
		a.change({ body: 'two' });
		await vi.advanceTimersByTimeAsync(100);
		expect(save).toHaveBeenCalledTimes(1);
		release();
		await vi.advanceTimersByTimeAsync(0);
		expect(save).toHaveBeenLastCalledWith({ body: 'two' });
		expect(save).toHaveBeenCalledTimes(2);
		expect(a.state).toBe('saved');
	});

	it('keeps failed edits for the next attempt', async () => {
		const save = vi
			.fn<(c: NoteChanges) => Promise<void>>()
			.mockRejectedValueOnce(new Error('offline'))
			.mockResolvedValue();
		const a = new Autosave(save, 100);
		a.change({ title: 'T' });
		await vi.advanceTimersByTimeAsync(100);
		expect(a.state).toBe('error');
		expect(a.dirty).toBe(true);
		a.change({ body: 'b' });
		await vi.advanceTimersByTimeAsync(100);
		expect(save).toHaveBeenLastCalledWith({ title: 'T', body: 'b' });
		expect(a.state).toBe('saved');
	});

	it('reports unsaved edits, including those being sent', async () => {
		let release!: () => void;
		const save = vi
			.fn<(c: NoteChanges) => Promise<void>>()
			.mockImplementation(() => new Promise((r) => (release = r)));
		const a = new Autosave(save, 100);
		a.change({ title: 'T' });
		await vi.advanceTimersByTimeAsync(100);
		a.change({ body: 'b' });
		expect(a.unsaved).toEqual({ title: 'T', body: 'b' });
		release();
		await vi.advanceTimersByTimeAsync(0);
		expect(a.unsaved).toEqual({ body: 'b' });
	});

	it('forgets everything once cancelled, even a save failing afterwards', async () => {
		let fail!: (e: Error) => void;
		const save = vi
			.fn<(c: NoteChanges) => Promise<void>>()
			.mockImplementationOnce(() => new Promise((_, r) => (fail = r)))
			.mockResolvedValue();
		const a = new Autosave(save, 100);
		a.change({ title: 'T' });
		await vi.advanceTimersByTimeAsync(100);
		a.cancel();
		fail(new Error('gone'));
		await vi.advanceTimersByTimeAsync(500);
		a.change({ body: 'late' });
		await a.flush();
		expect(save).toHaveBeenCalledTimes(1);
		expect(a.state).toBe('idle');
		expect(a.dirty).toBe(false);
	});
});
