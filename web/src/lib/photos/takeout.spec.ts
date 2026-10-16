import { describe, expect, it } from 'vitest';
import { failuresCsv, newer, percent, stepOf, uploadIdOf, type ImportJob } from './takeout.js';

const job = (over: Partial<ImportJob>): ImportJob => ({
	id: 'j1',
	owner: 'u1',
	source: 'upload',
	status: 'running',
	total: 0,
	processed: 0,
	imported: 0,
	duplicates: 0,
	skipped: 0,
	undated: 0,
	failed: 0,
	albums: 0,
	...over
});

describe('stepOf', () => {
	it('shows progress while a job is unfinished', () => {
		for (const status of ['queued', 'scanning', 'running'] as const)
			expect(stepOf(job({ status }), 'j1')).toBe('progress');
	});
	it('shows the report of a finished job until it is dismissed', () => {
		expect(stepOf(job({ status: 'done' }), null)).toBe('report');
		expect(stepOf(job({ status: 'failed' }), 'other')).toBe('report');
		expect(stepOf(job({ status: 'cancelled' }), 'j1')).toBeNull();
		expect(stepOf(null, null)).toBeNull();
	});
});

describe('percent', () => {
	it('is bounded and rounded', () => {
		expect(percent(job({ total: 3, processed: 1 }))).toBe(33);
		expect(percent(job({ total: 2, processed: 5 }))).toBe(100);
		expect(percent(job({ status: 'scanning' }))).toBe(0);
		expect(percent(job({ status: 'done' }))).toBe(100);
	});
});

describe('failuresCsv', () => {
	it('quotes fields and neutralises formulas', () => {
		const csv = failuresCsv(
			[
				{ path: 'Takeout/a, b.jpg', reason: 'unreadable' },
				{ path: '=HYPERLINK("x")', reason: 'too_large' }
			],
			['File', 'Reason'],
			(r) => (r === 'unreadable' ? 'Unreadable' : 'Too "large"')
		);
		expect(csv).toBe(
			'File,Reason\r\n"Takeout/a, b.jpg",Unreadable\r\n"\'=HYPERLINK(""x"")","Too ""large"""\r\n'
		);
	});
});

describe('uploadIdOf', () => {
	it('takes the last path segment', () => {
		expect(uploadIdOf('http://h/api/v1/uploads/abc123')).toBe('abc123');
		expect(uploadIdOf('/api/v1/uploads/abc123/')).toBe('abc123');
	});
});

describe('newer', () => {
	it('never lets a stale answer replace a newer event', () => {
		const done = job({ status: 'done', updated: '2026-10-17 10:00:05.000Z' });
		const stale = job({ status: 'running', updated: '2026-10-17 10:00:01.000Z' });
		expect(newer(done, stale)).toBe(done);
		expect(newer(stale, done)).toBe(done);
		expect(newer(null, stale)).toBe(stale);
	});
});
