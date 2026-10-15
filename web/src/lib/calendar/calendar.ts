import type { RecordModel } from 'pocketbase';
import { pb } from '#lib/pb.js';
import type { TagColor } from '#lib/tags/tags.svelte.js';
import {
	addDays,
	allDayKey,
	allDayPb,
	dayKey,
	formatRule,
	fromPb,
	parseRule,
	toPb,
	type Freq
} from './recurrence.js';

/** A record of the `calendars` collection (ADR 0028). */
export interface Calendar extends RecordModel {
	owner: string;
	name: string;
	color: TagColor;
	/** The calendar created on the first visit; at most one per user (ADR 0028). */
	is_default: boolean;
	updated: string;
}

/** A record of the `events` collection: UTC times, all-day = whole dates, end exclusive. */
export interface CalEvent extends RecordModel {
	owner: string;
	calendar: string;
	title: string;
	description: string;
	location: string;
	start: string;
	end: string;
	all_day: boolean;
	/** '' or an RRULE in the subset of recurrence.ts. */
	rrule: string;
	uid: string;
	created: string;
	updated: string;
}

export const calendarsCol = () => pb.collection<Calendar>('calendars');
export const eventsCol = () => pb.collection<CalEvent>('events');

const byName = (a: Calendar, b: Calendar) =>
	a.name.localeCompare(b.name, undefined, { sensitivity: 'base' });
export const sortCalendars = (cals: Calendar[]) => [...cals].sort(byName);

/**
 * The user's calendars, creating the default one on the first visit. The server allows one default
 * calendar per user, so two devices doing this at once (in any language) end up with one: the
 * loser's create fails and it reads again.
 */
export async function loadCalendars(firstName: string): Promise<Calendar[]> {
	const list = await calendarsCol().getFullList({ batch: 200 });
	if (list.length) return sortCalendars(list);
	try {
		return [
			await calendarsCol().create({
				owner: pb.authStore.record?.id,
				name: firstName,
				color: 'green',
				is_default: true
			})
		];
	} catch {
		return sortCalendars(await calendarsCol().getFullList({ batch: 200 }));
	}
}

// shortcut: loads every event of the user (series need their first occurrence); filter by range
// on the server once calendars hold many thousands of events.
export const loadEvents = () => eventsCol().getFullList({ batch: 500, sort: 'start' });

const HIDDEN_KEY = 'alcove.calendar.hidden';

/** Calendars the viewer chose to hide in this browser (a per-browser convenience). */
export function readHidden(): string[] {
	try {
		const v: unknown = JSON.parse(localStorage.getItem(HIDDEN_KEY) ?? '[]');
		return Array.isArray(v) ? v.filter((x) => typeof x === 'string') : [];
	} catch {
		return [];
	}
}

export function writeHidden(ids: string[]) {
	try {
		localStorage.setItem(HIDDEN_KEY, JSON.stringify(ids));
	} catch {
		// Private windows: the choice lasts for this page only.
	}
}

export type Repeat = 'none' | Freq;
export type Ends = 'never' | 'until' | 'count';

/** The event dialog's fields. Days are day keys; times "HH:MM" in the device time zone. */
export interface Draft {
	title: string;
	allDay: boolean;
	startDay: string;
	startTime: string;
	/** Last day of the event (inclusive, as people say it). */
	endDay: string;
	endTime: string;
	calendar: string;
	repeat: Repeat;
	ends: Ends;
	until: string;
	count: number;
	location: string;
	description: string;
}

const hm = (d: Date) =>
	`${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
const at = (day: string, time: string) => new Date(`${day}T${time || '00:00'}:00`);

/** A one-hour event on `day`: from the next full hour today, from 9:00 another day. */
export function newDraft(day: string, calendar: string, now = new Date()): Draft {
	let start = at(day, '09:00');
	if (day === dayKey(now)) {
		start = new Date(now);
		start.setHours(now.getHours() + 1, 0, 0, 0);
		if (dayKey(start) !== day) start = at(day, '23:00');
	}
	const end = new Date(start.getTime() + 3_600_000);
	return {
		title: '',
		allDay: false,
		startDay: day,
		startTime: hm(start),
		endDay: dayKey(end),
		endTime: hm(end),
		calendar,
		repeat: 'none',
		ends: 'never',
		until: addDays(day, 30),
		count: 10,
		location: '',
		description: ''
	};
}

export function draftFromEvent(ev: CalEvent): Draft {
	const rule = ev.rrule ? parseRule(ev.rrule, ev.all_day) : null;
	const base = {
		title: ev.title,
		allDay: ev.all_day,
		calendar: ev.calendar,
		repeat: (rule?.freq ?? 'none') as Repeat,
		ends: (rule?.count ? 'count' : rule?.until ? 'until' : 'never') as Ends,
		count: rule?.count ?? 10,
		location: ev.location,
		description: ev.description
	};
	if (ev.all_day) {
		const startDay = allDayKey(ev.start);
		return {
			...base,
			startDay,
			startTime: '09:00',
			endDay: addDays(allDayKey(ev.end), -1),
			endTime: '10:00',
			until: rule?.until ?? addDays(startDay, 30)
		};
	}
	const s = fromPb(ev.start);
	const e = fromPb(ev.end);
	return {
		...base,
		startDay: dayKey(s),
		startTime: hm(s),
		endDay: dayKey(e),
		endTime: hm(e),
		until: rule?.until ?? addDays(dayKey(s), 30)
	};
}

export type DraftError = 'title' | 'end' | 'until' | 'count' | null;

export function validateDraft(d: Draft): DraftError {
	if (!d.title.trim()) return 'title';
	if (!d.startDay || !d.endDay) return 'end';
	if (d.allDay ? d.endDay < d.startDay : at(d.endDay, d.endTime) < at(d.startDay, d.startTime))
		return 'end';
	if (d.repeat !== 'none' && d.ends === 'until' && (!d.until || d.until < d.startDay))
		return 'until';
	if (d.repeat !== 'none' && d.ends === 'count' && !(d.count >= 1 && d.count <= 999))
		return 'count';
	return null;
}

/** The record fields of a valid draft. */
export function draftToRecord(d: Draft) {
	const rule =
		d.repeat === 'none'
			? null
			: {
					freq: d.repeat,
					count: d.ends === 'count' ? Math.round(d.count) : undefined,
					until: d.ends === 'until' ? d.until : undefined
				};
	return {
		title: d.title.trim(),
		all_day: d.allDay,
		start: d.allDay ? allDayPb(d.startDay) : toPb(at(d.startDay, d.startTime)),
		end: d.allDay ? allDayPb(addDays(d.endDay, 1)) : toPb(at(d.endDay, d.endTime)),
		rrule: formatRule(rule, d.allDay),
		calendar: d.calendar,
		location: d.location.trim(),
		description: d.description
	};
}

/** Moving the start moves the end with it, so the event keeps its length. */
export function moveStart(d: Draft, startDay: string, startTime: string): Draft {
	if (!startDay) return { ...d, startDay, startTime };
	if (d.allDay || !d.startTime || !d.endTime) {
		const shift = d.startDay
			? Math.round(
					(at(startDay, '12:00').getTime() - at(d.startDay, '12:00').getTime()) / 86_400_000
				)
			: 0;
		return { ...d, startDay, startTime, endDay: d.endDay ? addDays(d.endDay, shift) : startDay };
	}
	const length = at(d.endDay, d.endTime).getTime() - at(d.startDay, d.startTime).getTime();
	const end = new Date(at(startDay, startTime).getTime() + Math.max(0, length));
	return { ...d, startDay, startTime, endDay: dayKey(end), endTime: hm(end) };
}
