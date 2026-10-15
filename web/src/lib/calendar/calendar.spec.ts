import { afterEach, describe, expect, it, vi } from 'vitest';

vi.mock('#lib/pb.js', () => ({ pb: {} }));

const { draftFromEvent, draftToRecord, moveStart, newDraft, validateDraft } =
	await import('./calendar');
type CalEvent = import('./calendar').CalEvent;

const savedTz = process.env.TZ;
afterEach(() => {
	process.env.TZ = savedTz;
});

const record = (fields: Partial<CalEvent>) =>
	({
		id: 'e1',
		calendar: 'c1',
		title: 'Trip',
		description: '',
		location: '',
		rrule: '',
		all_day: false,
		...fields
	}) as CalEvent;

describe('drafts', () => {
	it('stores an all-day event as whole UTC dates with an exclusive end, in any time zone', () => {
		for (const tz of ['America/Los_Angeles', 'Asia/Tokyo']) {
			process.env.TZ = tz;
			const d = {
				...newDraft('2026-10-24', 'c1'),
				title: 'Trip',
				allDay: true,
				endDay: '2026-10-26'
			};
			const rec = draftToRecord(d);
			expect([rec.start, rec.end]).toEqual([
				'2026-10-24 00:00:00.000Z',
				'2026-10-27 00:00:00.000Z'
			]);
			const back = draftFromEvent(record(rec));
			expect([back.startDay, back.endDay, back.allDay]).toEqual(['2026-10-24', '2026-10-26', true]);
		}
	});

	it('stores a timed event in UTC and reads it back in local time', () => {
		process.env.TZ = 'Europe/Paris';
		const d = {
			...newDraft('2026-10-20', 'c1'),
			title: ' Dentist ',
			startTime: '09:30',
			endTime: '10:15',
			repeat: 'WEEKLY' as const,
			ends: 'count' as const,
			count: 4
		};
		const rec = draftToRecord(d);
		expect(rec).toMatchObject({
			title: 'Dentist',
			start: '2026-10-20 07:30:00.000Z',
			end: '2026-10-20 08:15:00.000Z',
			rrule: 'FREQ=WEEKLY;COUNT=4'
		});
		const back = draftFromEvent(record(rec));
		expect(back).toMatchObject({
			startTime: '09:30',
			endTime: '10:15',
			repeat: 'WEEKLY',
			count: 4
		});
	});

	it('starts new events at the next hour today, at 9:00 another day', () => {
		process.env.TZ = 'UTC';
		const now = new Date('2026-10-15T14:20:00Z');
		expect(newDraft('2026-10-15', 'c', now)).toMatchObject({
			startTime: '15:00',
			endTime: '16:00'
		});
		expect(newDraft('2026-10-16', 'c', now)).toMatchObject({
			startTime: '09:00',
			endTime: '10:00'
		});
		const late = new Date('2026-10-15T23:30:00Z');
		expect(newDraft('2026-10-15', 'c', late)).toMatchObject({
			startTime: '23:00',
			endDay: '2026-10-16',
			endTime: '00:00'
		});
	});

	it('validates the title, the end and the repeat end', () => {
		process.env.TZ = 'UTC';
		const d = { ...newDraft('2026-10-20', 'c'), title: 'x' };
		expect(validateDraft(d)).toBeNull();
		expect(validateDraft({ ...d, title: ' ' })).toBe('title');
		expect(validateDraft({ ...d, endTime: '08:00' })).toBe('end');
		expect(validateDraft({ ...d, allDay: true, endDay: '2026-10-19' })).toBe('end');
		expect(validateDraft({ ...d, repeat: 'DAILY', ends: 'until', until: '2026-10-01' })).toBe(
			'until'
		);
		expect(validateDraft({ ...d, repeat: 'DAILY', ends: 'count', count: 0 })).toBe('count');
	});

	it('starts at 9:00 and moves all-day events by whole days on DST days', () => {
		process.env.TZ = 'Europe/Paris';
		expect(newDraft('2026-03-29', 'c', new Date('2026-03-01T12:00:00Z'))).toMatchObject({
			startTime: '09:00',
			endTime: '10:00'
		});
		const d = { ...newDraft('2026-03-28', 'c'), allDay: true, endDay: '2026-03-29' };
		expect(moveStart(d, '2026-03-29', '09:00').endDay).toBe('2026-03-30');
	});

	it('moves the end with the start', () => {
		process.env.TZ = 'UTC';
		const d = { ...newDraft('2026-10-20', 'c'), startTime: '09:00', endTime: '10:30' };
		expect(moveStart(d, '2026-10-22', '23:00')).toMatchObject({
			endDay: '2026-10-23',
			endTime: '00:30'
		});
		const allDay = { ...d, allDay: true, endDay: '2026-10-21' };
		expect(moveStart(allDay, '2026-10-25', '09:00').endDay).toBe('2026-10-26');
	});
});
