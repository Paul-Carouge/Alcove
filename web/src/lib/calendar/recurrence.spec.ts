import { afterEach, describe, expect, it } from 'vitest';
import {
	addDays,
	allDayPb,
	dayKey,
	expand,
	formatRule,
	onDay,
	parseRule,
	toPb,
	type EventTimes
} from './recurrence';

const savedTz = process.env.TZ;
afterEach(() => {
	process.env.TZ = savedTz;
});

const timed = (start: string, end: string, rrule = ''): EventTimes => ({
	start,
	end,
	all_day: false,
	rrule
});
const allDay = (first: string, afterLast: string, rrule = ''): EventTimes => ({
	start: allDayPb(first),
	end: allDayPb(afterLast),
	all_day: true,
	rrule
});
const days = (ev: EventTimes, from: string, to: string) =>
	expand([ev], from, to).map((o) => o.firstDay);

describe('rules', () => {
	it('reads and writes the supported subset', () => {
		expect(parseRule('FREQ=WEEKLY')).toEqual({ freq: 'WEEKLY' });
		expect(parseRule('FREQ=DAILY;COUNT=5')).toEqual({ freq: 'DAILY', count: 5 });
		expect(parseRule('FREQ=YEARLY;UNTIL=20301231', true)).toEqual({
			freq: 'YEARLY',
			until: '2030-12-31'
		});
		expect(parseRule('FREQ=WEEKLY;BYDAY=MO')).toBeNull();
		expect(formatRule({ freq: 'MONTHLY', count: 3 }, false)).toBe('FREQ=MONTHLY;COUNT=3');
		expect(formatRule({ freq: 'DAILY', until: '2026-11-02' }, true)).toBe(
			'FREQ=DAILY;UNTIL=20261102'
		);
		expect(formatRule(null, true)).toBe('');
	});

	it('ends a timed series at the end of the chosen local day, and reads it back', () => {
		process.env.TZ = 'Europe/Paris';
		const s = formatRule({ freq: 'DAILY', until: '2026-11-02' }, false);
		expect(s).toBe('FREQ=DAILY;UNTIL=20261102T225959Z');
		expect(parseRule(s)).toEqual({
			freq: 'DAILY',
			until: '2026-11-02',
			untilAt: new Date('2026-11-02T22:59:59Z')
		});
		// The DST day itself (Paris moves to summer time on 29 March).
		const dst = formatRule({ freq: 'DAILY', until: '2026-03-29' }, false);
		expect(dst).toBe('FREQ=DAILY;UNTIL=20260329T215959Z');
		expect(parseRule(dst)?.until).toBe('2026-03-29');
	});
});

describe('expand', () => {
	it('returns a single event overlapping the range', () => {
		process.env.TZ = 'UTC';
		const ev = timed('2026-10-20 09:00:00.000Z', '2026-10-20 10:00:00.000Z');
		expect(days(ev, '2026-10-01', '2026-11-01')).toEqual(['2026-10-20']);
		expect(days(ev, '2026-10-21', '2026-11-01')).toEqual([]);
	});

	it('repeats daily and weekly with COUNT and UNTIL', () => {
		process.env.TZ = 'UTC';
		const daily = timed(
			'2026-10-01 08:00:00.000Z',
			'2026-10-01 08:30:00.000Z',
			'FREQ=DAILY;COUNT=3'
		);
		expect(days(daily, '2026-09-01', '2026-12-01')).toEqual([
			'2026-10-01',
			'2026-10-02',
			'2026-10-03'
		]);
		const weekly = timed(
			'2026-10-05 08:00:00.000Z',
			'2026-10-05 09:00:00.000Z',
			'FREQ=WEEKLY;UNTIL=20261026T235959Z'
		);
		expect(days(weekly, '2026-10-01', '2026-12-01')).toEqual([
			'2026-10-05',
			'2026-10-12',
			'2026-10-19',
			'2026-10-26'
		]);
	});

	it('jumps to a far range and keeps the series index', () => {
		process.env.TZ = 'UTC';
		const ev = timed('2020-01-01 08:00:00.000Z', '2020-01-01 09:00:00.000Z', 'FREQ=DAILY');
		const occ = expand([ev], '2026-10-15', '2026-10-17');
		expect(occ.map((o) => [o.firstDay, o.index])).toEqual([
			['2026-10-15', 2479],
			['2026-10-16', 2480]
		]);
		const counted = timed(
			'2026-01-01 08:00:00.000Z',
			'2026-01-01 09:00:00.000Z',
			'FREQ=DAILY;COUNT=288'
		);
		expect(days(counted, '2026-10-15', '2026-10-17')).toEqual(['2026-10-15']);
	});

	it('skips months without the day, like RFC 5545', () => {
		process.env.TZ = 'UTC';
		const ev = allDay('2026-01-31', '2026-02-01', 'FREQ=MONTHLY;COUNT=4');
		expect(days(ev, '2026-01-01', '2027-01-01')).toEqual([
			'2026-01-31',
			'2026-03-31',
			'2026-05-31',
			'2026-07-31'
		]);
		const leap = allDay('2024-02-29', '2024-03-01', 'FREQ=YEARLY');
		expect(days(leap, '2024-01-01', '2033-01-01')).toEqual([
			'2024-02-29',
			'2028-02-29',
			'2032-02-29'
		]);
	});

	it('keeps the local time of a weekly event across a DST change', () => {
		process.env.TZ = 'Europe/Paris';
		// 9:00 in Paris, summer time (UTC+2); Paris switches to UTC+1 on 25 October 2026.
		const ev = timed('2026-10-19 07:00:00.000Z', '2026-10-19 08:00:00.000Z', 'FREQ=WEEKLY');
		const occ = expand([ev], '2026-10-19', '2026-11-03');
		expect(occ.map((o) => [o.firstDay, o.start.getHours()])).toEqual([
			['2026-10-19', 9],
			['2026-10-26', 9],
			['2026-11-02', 9]
		]);
		expect(toPb(occ[1].start)).toBe('2026-10-26 08:00:00.000Z');
	});

	it('shows a multi-day event on every day it covers', () => {
		process.env.TZ = 'UTC';
		const trip = allDay('2026-10-24', '2026-10-27');
		const [o] = expand([trip], '2026-10-01', '2026-11-01');
		expect([o.firstDay, o.lastDay]).toEqual(['2026-10-24', '2026-10-26']);
		expect(onDay([o], '2026-10-25')).toHaveLength(1);
		expect(onDay([o], '2026-10-27')).toHaveLength(0);
		// Seen from the middle of it.
		expect(days(trip, '2026-10-26', '2026-10-30')).toEqual(['2026-10-24']);
		// A timed event ending at midnight stays on its day.
		const late = timed('2026-10-20 22:00:00.000Z', '2026-10-21 00:00:00.000Z');
		const [l] = expand([late], '2026-10-01', '2026-11-01');
		expect([l.firstDay, l.lastDay]).toEqual(['2026-10-20', '2026-10-20']);
	});

	it('repeats multi-day events and keeps those that started before the range', () => {
		process.env.TZ = 'UTC';
		const ev = allDay('2026-10-03', '2026-10-06', 'FREQ=WEEKLY');
		expect(days(ev, '2026-10-12', '2026-10-13')).toEqual(['2026-10-10']);
	});

	it('sorts all-day events first, then by time', () => {
		process.env.TZ = 'UTC';
		const occ = expand(
			[
				timed('2026-10-20 15:00:00.000Z', '2026-10-20 16:00:00.000Z'),
				allDay('2026-10-20', '2026-10-21'),
				timed('2026-10-20 08:00:00.000Z', '2026-10-20 09:00:00.000Z')
			],
			'2026-10-20',
			'2026-10-21'
		);
		expect(occ.map((o) => (o.event.all_day ? 'all' : o.start.getUTCHours()))).toEqual([
			'all',
			8,
			15
		]);
	});
});

describe('UNTIL', () => {
	it('stops a timed series at the UNTIL instant, not at the end of its day', () => {
		const ev = timed(
			'2026-10-18 13:00:00.000Z',
			'2026-10-18 14:00:00.000Z',
			'FREQ=DAILY;UNTIL=20261020T120000Z'
		);
		// In Tokyo the 20th's occurrence (22:00) and UNTIL (21:00) share a day: still excluded.
		for (const tz of ['Asia/Tokyo', 'UTC', 'America/New_York']) {
			process.env.TZ = tz;
			expect(expand([ev], '2026-10-01', '2026-11-01')).toHaveLength(2);
		}
	});
});

describe('time zones', () => {
	for (const tz of [
		'Pacific/Honolulu',
		'UTC',
		'Europe/Paris',
		'Asia/Tokyo',
		'Pacific/Kiritimati'
	]) {
		it(`keeps an all-day event on its date in ${tz}`, () => {
			process.env.TZ = tz;
			const ev = allDay('2026-10-24', '2026-10-25', 'FREQ=YEARLY;UNTIL=20271024');
			const occ = expand([ev], '2026-01-01', '2028-01-01');
			expect(occ.map((o) => [o.firstDay, o.lastDay])).toEqual([
				['2026-10-24', '2026-10-24'],
				['2027-10-24', '2027-10-24']
			]);
			expect(dayKey(occ[0].start)).toBe('2026-10-24');
		});
	}

	it('shows a timed event on the local day', () => {
		const ev = timed('2026-10-20 23:30:00.000Z', '2026-10-21 00:30:00.000Z');
		process.env.TZ = 'Asia/Tokyo';
		expect(days(ev, '2026-10-01', '2026-11-01')).toEqual(['2026-10-21']);
		process.env.TZ = 'America/New_York';
		expect(days(ev, '2026-10-01', '2026-11-01')).toEqual(['2026-10-20']);
	});

	it('does day arithmetic without time zones', () => {
		process.env.TZ = 'Europe/Paris';
		expect(addDays('2026-10-24', 2)).toBe('2026-10-26');
		expect(addDays('2026-03-28', 1)).toBe('2026-03-29');
		expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
	});
});
