/*
 * Dates and recurrence of calendar events (ADR 0028), without a date library.
 *
 * - Timed events are UTC instants, shown in the device time zone.
 * - All-day events cover whole dates: start = first day at 00:00Z, end = the day after the last one
 *   (exclusive, like iCalendar's DTEND). They are read as dates, never as instants, so they stay on
 *   the same day in every time zone.
 * - A "day key" is a calendar date written YYYY-MM-DD.
 */

export type Freq = 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY';

/** The recurrence subset Alcove edits and expands (the server refuses anything else). */
export interface Rule {
	freq: Freq;
	/** Number of occurrences, the first one included. */
	count?: number;
	/** Day key of the last day an occurrence may start on. */
	until?: string;
	/** The exact UNTIL instant of a timed series (a UTC date-time in the rule), used to expand it. */
	untilAt?: Date;
}

/** What expansion needs from an event record. */
export interface EventTimes {
	start: string;
	end: string;
	all_day: boolean;
	rrule: string;
}

export interface Occurrence<E extends EventTimes = EventTimes> {
	event: E;
	/** Index in the series (0 for the first occurrence). */
	index: number;
	/** Timed events: instants. All-day events: local midnight of the first day / the day after the last. */
	start: Date;
	end: Date;
	/** First and last day (inclusive) the occurrence appears on, in the viewer's calendar. */
	firstDay: string;
	lastDay: string;
}

const pad = (n: number, w = 2) => String(n).padStart(w, '0');

/** Day key of a date in the device time zone. */
export const dayKey = (d: Date) =>
	`${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

/** Local midnight of a day key. */
export function fromKey(key: string): Date {
	const [y, m, d] = key.split('-').map(Number);
	return new Date(y, m - 1, d);
}

/** The day key `n` days after `key` (calendar arithmetic, no time zone involved). */
export function addDays(key: string, n: number): string {
	const [y, m, d] = key.split('-').map(Number);
	const t = new Date(Date.UTC(y, m - 1, d + n));
	return `${t.getUTCFullYear()}-${pad(t.getUTCMonth() + 1)}-${pad(t.getUTCDate())}`;
}

/** Whole days from key `a` to key `b`. */
export function daysBetween(a: string, b: string): number {
	const ms = (k: string) => {
		const [y, m, d] = k.split('-').map(Number);
		return Date.UTC(y, m - 1, d);
	};
	return Math.round((ms(b) - ms(a)) / 86_400_000);
}

/** PocketBase's date format: "2026-10-15 10:00:00.000Z". */
export const toPb = (d: Date) => d.toISOString().replace('T', ' ');

/** Parses PocketBase's date format (or ISO). */
export const fromPb = (s: string) => new Date(s.replace(' ', 'T'));

/** The stored value of an all-day boundary: the date at 00:00 UTC. */
export const allDayPb = (key: string) => `${key} 00:00:00.000Z`;

/** The date of an all-day boundary, read as a date (its UTC calendar day). */
export const allDayKey = (pbDate: string) => pbDate.slice(0, 10);

const RULE =
	/^FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY)(?:;(?:COUNT=(\d{1,3})|UNTIL=(\d{8})(T\d{6}Z)?))?$/;

/**
 * Reads an RRULE string. `allDay` decides how a date-time UNTIL is turned into a day: for timed
 * events it is the local day of that instant.
 */
export function parseRule(rrule: string, allDay = false): Rule | null {
	const m = RULE.exec(rrule.trim());
	if (!m) return null;
	const rule: Rule = { freq: m[1] as Freq };
	if (m[2]) rule.count = Number(m[2]);
	if (m[3]) {
		const key = `${m[3].slice(0, 4)}-${m[3].slice(4, 6)}-${m[3].slice(6, 8)}`;
		if (m[4] && !allDay) {
			const t = m[4];
			rule.untilAt = new Date(`${key}T${t.slice(1, 3)}:${t.slice(3, 5)}:${t.slice(5, 7)}Z`);
			rule.until = dayKey(rule.untilAt);
		} else {
			rule.until = key;
		}
	}
	return rule;
}

/**
 * Writes an RRULE string. All-day series end on a date (UNTIL=YYYYMMDD, as RFC 5545 requires when
 * DTSTART is a date); timed series end at the last second of that local day, in UTC.
 */
export function formatRule(rule: Rule | null, allDay: boolean): string {
	if (!rule) return '';
	let s = `FREQ=${rule.freq}`;
	if (rule.count) s += `;COUNT=${rule.count}`;
	else if (rule.until) {
		if (allDay) s += `;UNTIL=${rule.until.replaceAll('-', '')}`;
		else {
			const end = fromKey(rule.until);
			end.setHours(23, 59, 59);
			s += `;UNTIL=${end.toISOString().slice(0, 19).replace(/[-:]/g, '')}Z`;
		}
	}
	return s;
}

/** The n-th step of a series from local date parts; null when that date does not exist (31 April). */
function step(
	y: number,
	mo: number,
	d: number,
	freq: Freq,
	n: number,
	make: (y: number, mo: number, d: number) => Date,
	read: (t: Date) => [number, number, number]
): Date | null {
	const t =
		freq === 'DAILY'
			? make(y, mo, d + n)
			: freq === 'WEEKLY'
				? make(y, mo, d + 7 * n)
				: freq === 'MONTHLY'
					? make(y, mo + n, d)
					: make(y + n, mo, d);
	// RFC 5545: an occurrence on a day the month does not have is skipped, not moved.
	if (freq === 'MONTHLY' || freq === 'YEARLY') {
		if (read(t)[2] !== d) return null;
	}
	return t;
}

// Guards against runaway loops on absurd data (a daily rule since year 1).
const MAX_STEPS = 20_000;

/**
 * Occurrences of `events` that appear on at least one day of [fromDay, toDay) (day keys in the device
 * time zone), sorted by start. Repeating timed events keep their local clock time across DST changes.
 */
export function expand<E extends EventTimes>(
	events: E[],
	fromDay: string,
	toDay: string
): Occurrence<E>[] {
	const out: Occurrence<E>[] = [];
	for (const ev of events) {
		const rule = ev.rrule ? parseRule(ev.rrule, ev.all_day) : null;
		if (ev.all_day) expandAllDay(ev, rule, fromDay, toDay, out);
		else expandTimed(ev, rule, fromDay, toDay, out);
	}
	return out.sort(
		(a, b) =>
			a.firstDay.localeCompare(b.firstDay) ||
			Number(b.event.all_day) - Number(a.event.all_day) ||
			a.start.getTime() - b.start.getTime()
	);
}

function expandAllDay<E extends EventTimes>(
	ev: E,
	rule: Rule | null,
	fromDay: string,
	toDay: string,
	out: Occurrence<E>[]
) {
	const first = allDayKey(ev.start);
	const days = Math.max(1, daysBetween(first, allDayKey(ev.end)));
	const [y, mo, d] = first.split('-').map(Number);
	const utc = (y: number, mo: number, d: number) => new Date(Date.UTC(y, mo, d));
	const read = (t: Date): [number, number, number] => [
		t.getUTCFullYear(),
		t.getUTCMonth(),
		t.getUTCDate()
	];
	const toKey = (t: Date) =>
		`${t.getUTCFullYear()}-${pad(t.getUTCMonth() + 1)}-${pad(t.getUTCDate())}`;
	const emit = (index: number, startKey: string) => {
		const lastDay = addDays(startKey, days - 1);
		if (startKey >= toDay || lastDay < fromDay) return;
		out.push({
			event: ev,
			index,
			start: fromKey(startKey),
			end: fromKey(addDays(startKey, days)),
			firstDay: startKey,
			lastDay
		});
	};
	if (!rule) return emit(0, first);
	series(
		rule,
		y,
		mo - 1,
		d,
		utc,
		read,
		(t, index) => {
			const key = toKey(t);
			if (rule.until && key > rule.until) return false;
			if (key >= toDay) return false;
			emit(index, key);
			return true;
		},
		fromDay,
		first,
		days
	);
}

function expandTimed<E extends EventTimes>(
	ev: E,
	rule: Rule | null,
	fromDay: string,
	toDay: string,
	out: Occurrence<E>[]
) {
	const start = fromPb(ev.start);
	const duration = Math.max(0, fromPb(ev.end).getTime() - start.getTime());
	const from = fromKey(fromDay).getTime();
	const to = fromKey(toDay).getTime();
	const emit = (index: number, s: Date) => {
		const e = new Date(s.getTime() + duration);
		// An event ending exactly at midnight does not appear on the next day.
		const last = new Date(Math.max(s.getTime(), e.getTime() - 1));
		if (s.getTime() >= to || last.getTime() < from) return;
		out.push({ event: ev, index, start: s, end: e, firstDay: dayKey(s), lastDay: dayKey(last) });
	};
	if (!rule) return emit(0, start);
	// shortcut: series follow the device's time zone (no TZID stored); add a tzid field with CalDAV.
	const h = start.getHours(),
		mi = start.getMinutes(),
		sec = start.getSeconds(),
		ms = start.getMilliseconds();
	const local = (y: number, mo: number, d: number) => new Date(y, mo, d, h, mi, sec, ms);
	const read = (t: Date): [number, number, number] => [t.getFullYear(), t.getMonth(), t.getDate()];
	const spanDays = Math.ceil(duration / 86_400_000) + 1;
	series(
		rule,
		start.getFullYear(),
		start.getMonth(),
		start.getDate(),
		local,
		read,
		(t, index) => {
			if (rule.untilAt ? t > rule.untilAt : rule.until && dayKey(t) > rule.until) return false;
			if (t.getTime() >= to) return false;
			emit(index, t);
			return true;
		},
		fromDay,
		dayKey(start),
		spanDays
	);
}

/**
 * Walks a series, calling `visit(date, index)` until it returns false or the series ends. Daily and
 * weekly series jump straight to the visible range (their dates never skip, so index = step).
 */
function series(
	rule: Rule,
	y: number,
	mo: number,
	d: number,
	make: (y: number, mo: number, d: number) => Date,
	read: (t: Date) => [number, number, number],
	visit: (t: Date, index: number) => boolean,
	fromDay: string,
	firstDay: string,
	spanDays: number
) {
	let n = 0;
	if (rule.freq === 'DAILY' || rule.freq === 'WEEKLY') {
		const every = rule.freq === 'DAILY' ? 1 : 7;
		// Start a little before the range so occurrences spanning into it are kept.
		n = Math.max(0, Math.floor((daysBetween(firstDay, fromDay) - spanDays) / every));
	}
	let index = n;
	for (let i = 0; i < MAX_STEPS; i++, n++) {
		if (rule.count !== undefined && index >= rule.count) return;
		const t = step(y, mo, d, rule.freq, n, make, read);
		if (!t) continue;
		if (!visit(t, index)) return;
		index++;
	}
}

/** Keeps occurrences that appear on `day` (a day key). */
export const onDay = <E extends EventTimes>(occs: Occurrence<E>[], day: string) =>
	occs.filter((o) => o.firstDay <= day && o.lastDay >= day);
