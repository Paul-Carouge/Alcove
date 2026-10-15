<script lang="ts">
	import {
		CalendarDays,
		ChevronLeft,
		ChevronRight,
		MapPin,
		Pencil,
		Plus,
		Repeat as RepeatIcon
	} from '@lucide/svelte';
	import CalendarDialog from '#lib/calendar/CalendarDialog.svelte';
	import EventDialog from '#lib/calendar/EventDialog.svelte';
	import {
		loadCalendars,
		loadEvents,
		readHidden,
		sortCalendars,
		writeHidden,
		type CalEvent,
		type Calendar
	} from '#lib/calendar/calendar.js';
	import {
		addDays,
		dayKey,
		expand,
		fromKey,
		onDay,
		type Occurrence
	} from '#lib/calendar/recurrence.js';
	import { onCalendarChange, onEventChange } from '#lib/drive/live.js';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import { TAG_COLORS } from '#lib/tags/tags.svelte.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';

	const locale = getLocale();
	const AGENDA_DAYS = 30;
	const MAX_CHIPS = 3;
	const phone = '(max-width: 600px)';

	let calendars = $state<Calendar[] | null>(null);
	let events = $state<CalEvent[] | null>(null);
	let failed = $state(false);
	let hidden = $state<string[]>(readHidden());
	let narrow = $state(matchMedia(phone).matches);
	// Phones open on the agenda: a month grid leaves no room for titles.
	let view = $state<'month' | 'agenda'>(matchMedia(phone).matches ? 'agenda' : 'month');
	let today = $state(dayKey(new Date()));
	/** Month view: a day of the month shown. Agenda: its first day. */
	let anchor = $state(dayKey(new Date()));

	let eventOpen = $state(false);
	let editing = $state<CalEvent | null>(null);
	let newDay = $state(dayKey(new Date()));
	let calOpen = $state(false);
	let editingCal = $state<Calendar | null>(null);

	// Week start of the language (Monday in French, Sunday in US English); Monday when unknown.
	const weekStart = (() => {
		try {
			const info = (
				new Intl.Locale(locale) as Intl.Locale & { getWeekInfo?: () => { firstDay: number } }
			).getWeekInfo?.();
			return (info?.firstDay ?? 1) % 7;
		} catch {
			return 1;
		}
	})();

	const fmt = (o: Intl.DateTimeFormatOptions) => new Intl.DateTimeFormat(locale, o);
	const monthFmt = fmt({ month: 'long', year: 'numeric' });
	const longDayFmt = fmt({ weekday: 'long', day: 'numeric', month: 'long' });
	const shortDayFmt = fmt({ day: 'numeric', month: 'short' });
	const timeFmt = fmt({ hour: 'numeric', minute: '2-digit' });
	const longDay = (key: string) => longDayFmt.format(fromKey(key));

	const weekdays = Array.from({ length: 7 }, (_, i) => {
		// 2026-10-04 is a Sunday.
		const d = fromKey(addDays('2026-10-04', (weekStart + i) % 7));
		return { short: fmt({ weekday: 'short' }).format(d), long: fmt({ weekday: 'long' }).format(d) };
	});

	const monthStart = $derived(anchor.slice(0, 8) + '01');
	const grid = $derived.by(() => {
		const first = fromKey(monthStart);
		const start = addDays(monthStart, -((first.getDay() - weekStart + 7) % 7));
		const nextMonth = shiftMonth(monthStart, 1);
		const weeks: string[][] = [];
		for (let d = start; d < nextMonth; d = addDays(d, 7)) {
			weeks.push(Array.from({ length: 7 }, (_, i) => addDays(d, i)));
		}
		return { start, end: addDays(start, weeks.length * 7), weeks };
	});
	const range = $derived(
		view === 'month' ? [grid.start, grid.end] : [anchor, addDays(anchor, AGENDA_DAYS)]
	);
	const shownEvents = $derived((events ?? []).filter((e) => !hidden.includes(e.calendar)));
	const occs = $derived(expand(shownEvents, range[0], range[1]));
	const agendaDays = $derived(
		Array.from({ length: AGENDA_DAYS }, (_, i) => addDays(anchor, i))
			.map((day) => ({ day, list: onDay(occs, day) }))
			.filter((d) => d.list.length > 0)
	);
	const calById = $derived(new Map((calendars ?? []).map((c) => [c.id, c])));
	const period = $derived(
		view === 'month'
			? monthFmt.format(fromKey(monthStart))
			: m.calendar_range({
					from: shortDayFmt.format(fromKey(anchor)),
					to: shortDayFmt.format(fromKey(addDays(anchor, AGENDA_DAYS - 1)))
				})
	);

	function shiftMonth(key: string, n: number) {
		const [y, mo] = key.split('-').map(Number);
		const d = new Date(Date.UTC(y, mo - 1 + n, 1));
		return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-01`;
	}

	/** Token colours of an event's calendar, as custom properties. */
	function tone(calendarId: string) {
		const c = calById.get(calendarId)?.color;
		const t = c && (TAG_COLORS as readonly string[]).includes(c) ? c : 'gray';
		return `--tone: var(--color-tag-${t}); --tone-bg: var(--color-tag-${t}-bg)`;
	}

	function timeText(o: Occurrence<CalEvent>) {
		if (o.event.all_day) return m.calendar_all_day();
		return timeFmt.formatRange(o.start, o.end);
	}

	/** Realtime messages received while a load runs, applied on top of its result. */
	let buffer: (() => void)[] | null = null;

	async function load() {
		buffer = [];
		try {
			const [cals, evs] = await Promise.all([
				loadCalendars(m.calendar_default_name()),
				loadEvents()
			]);
			calendars = cals;
			events = evs;
			failed = false;
			const pending = buffer;
			buffer = null;
			pending.forEach((apply) => apply());
		} catch {
			buffer = null;
			failed = true;
		}
	}

	/** Runs a realtime change now, or after the load in progress. */
	const live = (apply: () => void) => (buffer ? buffer.push(apply) : apply());
	/** A late echo of an older version must not undo a newer one. */
	const stale = (
		list: { id: string; updated: string }[] | null,
		r: { id: string; updated: string }
	) => !!list?.some((x) => x.id === r.id && x.updated >= r.updated);

	function putEvent(ev: CalEvent) {
		if (!events) return;
		events = events.some((e) => e.id === ev.id)
			? events.map((e) => (e.id === ev.id ? ev : e))
			: [...events, ev];
	}
	const dropEvent = (id: string) => (events = (events ?? []).filter((e) => e.id !== id));
	function putCalendar(cal: Calendar) {
		if (!calendars) return;
		calendars = sortCalendars([...calendars.filter((c) => c.id !== cal.id), cal]);
	}
	function dropCalendar(id: string) {
		calendars = (calendars ?? []).filter((c) => c.id !== id);
		// Its events are deleted with it (cascade); realtime may not send each one.
		events = (events ?? []).filter((e) => e.calendar !== id);
	}

	$effect(() => {
		load();
		const media = matchMedia(phone);
		const onMedia = () => (narrow = media.matches);
		media.addEventListener('change', onMedia);
		// The date changes at midnight or when a sleeping laptop wakes up.
		const tick = setInterval(() => (today = dayKey(new Date())), 60_000);
		const offEvents = onEventChange<CalEvent>((e) =>
			live(() => {
				if (e.action === 'delete') dropEvent(e.record.id);
				else if (!stale(events, e.record)) putEvent(e.record);
			})
		);
		const offCalendars = onCalendarChange<Calendar>((e) =>
			live(() => {
				if (e.action === 'delete') dropCalendar(e.record.id);
				else if (!stale(calendars, e.record)) putCalendar(e.record);
			})
		);
		return () => {
			media.removeEventListener('change', onMedia);
			clearInterval(tick);
			offEvents();
			offCalendars();
		};
	});

	function move(n: number) {
		anchor = view === 'month' ? shiftMonth(monthStart, n) : addDays(anchor, n * AGENDA_DAYS);
	}

	function setView(v: 'month' | 'agenda') {
		if (v === view) return;
		// The agenda starts today when today is in the month shown, else on the 1st.
		if (v === 'agenda') anchor = today.slice(0, 7) === anchor.slice(0, 7) ? today : monthStart;
		view = v;
	}

	function create(day: string) {
		editing = null;
		newDay = day;
		eventOpen = true;
	}

	function openEvent(ev: CalEvent) {
		editing = ev;
		eventOpen = true;
	}

	function showDay(day: string) {
		anchor = day;
		view = 'agenda';
	}

	/** A click on the empty part of a day cell creates an event there (the day number does it by keyboard). */
	function cellClick(e: MouseEvent, day: string) {
		if (narrow) return;
		if ((e.target as HTMLElement).closest('button')) return;
		create(day);
	}

	function toggleCalendar(id: string, shown: boolean) {
		hidden = shown ? hidden.filter((h) => h !== id) : [...hidden, id];
		writeHidden(hidden);
	}

	function editCalendar(cal: Calendar | null) {
		editingCal = cal;
		calOpen = true;
	}
</script>

<svelte:head>
	<title>{m.nav_calendar()}</title>
</svelte:head>

<div class="head">
	<h1>{m.nav_calendar()}</h1>
	<Button onclick={() => create(view === 'agenda' && anchor > today ? anchor : today)}>
		<Plus size={16} aria-hidden="true" />{m.calendar_new_event()}
	</Button>
</div>

{#if failed}
	<Alert>{m.error_load()}</Alert>
{:else}
	<div class="layout">
		<div class="main">
			<div class="toolbar">
				<Button variant="secondary" onclick={() => (anchor = today)}>{m.calendar_today()}</Button>
				<div class="arrows">
					<button
						class="icon-btn"
						aria-label={view === 'month' ? m.calendar_previous_month() : m.calendar_previous_days()}
						title={view === 'month' ? m.calendar_previous_month() : m.calendar_previous_days()}
						onclick={() => move(-1)}
					>
						<ChevronLeft size={20} aria-hidden="true" />
					</button>
					<button
						class="icon-btn"
						aria-label={view === 'month' ? m.calendar_next_month() : m.calendar_next_days()}
						title={view === 'month' ? m.calendar_next_month() : m.calendar_next_days()}
						onclick={() => move(1)}
					>
						<ChevronRight size={20} aria-hidden="true" />
					</button>
				</div>
				<h2 class="period" aria-live="polite">{period}</h2>
				<div class="chips" role="radiogroup" aria-label={m.calendar_view()}>
					{#each [['month', m.calendar_month], ['agenda', m.calendar_agenda]] as const as [value, label] (value)}
						<button
							role="radio"
							aria-checked={view === value}
							class:on={view === value}
							onclick={() => setView(value)}>{label()}</button
						>
					{/each}
				</div>
			</div>

			{#if events === null}
				<div class="skeleton" aria-busy="true" aria-label={m.loading()}></div>
			{:else if view === 'month'}
				<table class="month" class:narrow>
					<caption class="visually-hidden">{period}</caption>
					<thead>
						<tr>
							{#each weekdays as w (w.long)}<th scope="col" abbr={w.long}>{w.short}</th>{/each}
						</tr>
					</thead>
					<tbody>
						{#each grid.weeks as week (week[0])}
							<tr>
								{#each week as day (day)}
									{@const list = onDay(occs, day)}
									<!-- Pointer shortcut only: the day button does the same by keyboard. -->
									<td
										class:out={day.slice(0, 7) !== monthStart.slice(0, 7)}
										class:today={day === today}
										aria-current={day === today ? 'date' : undefined}
										onclick={(e) => cellClick(e, day)}
									>
										<button
											class="day-num"
											aria-label={narrow
												? m.calendar_day_events({ date: longDay(day) })
												: m.calendar_new_event_on({ date: longDay(day) })}
											onclick={() => (narrow ? showDay(day) : create(day))}
											>{Number(day.slice(8))}</button
										>
										{#if narrow}
											<span class="dots" aria-hidden="true">
												{#each list.slice(0, MAX_CHIPS) as o (o.event.id + o.index)}
													<span class="dot" style={tone(o.event.calendar)}></span>
												{/each}
											</span>
										{:else}
											<ul class="day-events">
												{#each list.slice(0, MAX_CHIPS) as o (o.event.id + o.index)}
													<li>
														<button
															class="chip"
															class:all-day={o.event.all_day}
															style={tone(o.event.calendar)}
															onclick={() => openEvent(o.event)}
														>
															{#if !o.event.all_day && o.firstDay === day}
																<span class="time">{timeFmt.format(o.start)}</span>
															{/if}
															<span class="chip-title">{o.event.title}</span>
														</button>
													</li>
												{/each}
											</ul>
											{#if list.length > MAX_CHIPS}
												<button class="more" onclick={() => showDay(day)}>
													{m.calendar_more({ count: list.length - MAX_CHIPS })}
												</button>
											{/if}
										{/if}
									</td>
								{/each}
							</tr>
						{/each}
					</tbody>
				</table>
			{:else}
				<section class="agenda" aria-label={m.calendar_agenda_label()}>
					{#each agendaDays as { day, list } (day)}
						<h3 class="agenda-day" class:today={day === today}>
							{#if day === today}<span class="today-pill">{m.calendar_today()}</span>{/if}
							{longDay(day)}
						</h3>
						<ul class="rows">
							{#each list as o (o.event.id + o.index)}
								<li>
									<button
										class="row"
										style={tone(o.event.calendar)}
										onclick={() => openEvent(o.event)}
									>
										<span class="when">{timeText(o)}</span>
										<span class="bar" aria-hidden="true"></span>
										<span class="what">
											<span class="row-title">{o.event.title}</span>
											{#if o.event.location}
												<span class="loc"
													><MapPin size={14} aria-hidden="true" />{o.event.location}</span
												>
											{/if}
										</span>
										{#if o.event.rrule}
											<span class="repeat" title={m.calendar_repeats()}>
												<RepeatIcon size={16} aria-hidden="true" />
												<span class="visually-hidden">{m.calendar_repeats()}</span>
											</span>
										{/if}
									</button>
								</li>
							{/each}
						</ul>
					{:else}
						<div class="none">
							<span class="art" aria-hidden="true"
								><CalendarDays size={24} strokeWidth={1.75} /></span
							>
							<p class="muted" role="status">{m.calendar_agenda_empty()}</p>
						</div>
					{/each}
				</section>
			{/if}
		</div>

		<aside class="side" aria-labelledby="calendars-title">
			<h2 id="calendars-title" class="side-title">{m.calendar_calendars()}</h2>
			<ul class="cals">
				{#each calendars ?? [] as c (c.id)}
					<li style={tone(c.id)}>
						<label class="cal">
							<input
								type="checkbox"
								checked={!hidden.includes(c.id)}
								onchange={(e) => toggleCalendar(c.id, e.currentTarget.checked)}
							/>
							<span class="cal-name">{c.name}</span>
						</label>
						<button
							class="icon-btn"
							aria-label={m.calendar_edit_calendar_for({ name: c.name })}
							title={m.calendar_edit_calendar_for({ name: c.name })}
							onclick={() => editCalendar(c)}
						>
							<Pencil size={16} aria-hidden="true" />
						</button>
					</li>
				{/each}
			</ul>
			<Button variant="ghost" onclick={() => editCalendar(null)}>
				<Plus size={16} aria-hidden="true" />{m.calendar_new_calendar()}
			</Button>
		</aside>
	</div>
{/if}

<EventDialog
	bind:open={eventOpen}
	event={editing}
	day={newDay}
	calendars={calendars ?? []}
	onsaved={putEvent}
	ondeleted={dropEvent}
/>
<CalendarDialog
	bind:open={calOpen}
	calendar={editingCal}
	canDelete={(calendars?.length ?? 0) > 1}
	onsaved={putCalendar}
	ondeleted={dropCalendar}
/>

<style>
	.head {
		display: flex;
		align-items: flex-end;
		justify-content: space-between;
		flex-wrap: wrap;
		gap: var(--space-3);
		min-height: 3.5rem;
		margin: 0 0 var(--space-5);
	}
	.layout {
		display: grid;
		grid-template-columns: minmax(0, 1fr) 14rem;
		gap: var(--space-6);
		align-items: start;
	}
	.main {
		display: grid;
		gap: var(--space-4);
		min-width: 0;
	}
	.toolbar {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-2);
	}
	.arrows {
		display: flex;
	}
	.period {
		flex: 1;
		min-width: 10rem;
		margin: 0 var(--space-2);
		font-size: var(--text-xl);
		font-weight: var(--weight-medium);
		text-transform: capitalize;
	}
	.icon-btn {
		display: grid;
		place-items: center;
		flex: none;
		width: 2.75rem;
		height: 2.75rem;
		border: 0;
		border-radius: var(--radius-md);
		background: transparent;
		color: var(--color-text-muted);
		cursor: pointer;
	}
	.icon-btn:hover {
		background: var(--color-surface-sunken);
		color: var(--color-text);
	}
	.chips {
		display: inline-flex;
		gap: var(--space-1);
		padding: var(--space-1);
		border-radius: var(--radius-full);
		background: var(--color-surface-sunken);
	}
	.chips button {
		min-height: 2.25rem;
		padding: 0 var(--space-4);
		border: 0;
		border-radius: var(--radius-full);
		background: transparent;
		color: var(--color-text-muted);
		font: inherit;
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		cursor: pointer;
	}
	.chips button.on {
		background: var(--color-surface);
		color: var(--color-text);
		box-shadow: var(--shadow-sm);
	}
	.skeleton {
		height: 30rem;
		border-radius: var(--radius-lg);
		background: var(--color-surface-sunken);
		opacity: 0.6;
	}

	/* Month */
	.month {
		width: 100%;
		table-layout: fixed;
		border-collapse: separate;
		border-spacing: 0;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
		box-shadow: var(--shadow-sm);
		overflow: hidden;
	}
	.month th {
		padding: var(--space-2);
		border-bottom: 1px solid var(--color-border);
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		font-weight: var(--weight-medium);
		letter-spacing: 0.08em;
		text-transform: uppercase;
		text-align: start;
	}
	.month td {
		height: 7.5rem;
		padding: var(--space-1);
		vertical-align: top;
		border-top: 1px solid var(--color-border);
		border-inline-start: 1px solid var(--color-border);
		cursor: pointer;
	}
	.month tbody tr:first-child td {
		border-top: 0;
	}
	.month td:first-child {
		border-inline-start: 0;
	}
	.month td.out {
		background: color-mix(in srgb, var(--color-surface-sunken) 45%, transparent);
	}
	.month td.out .day-num {
		color: var(--color-text-muted);
	}
	.day-num {
		display: grid;
		place-items: center;
		min-width: 2rem;
		height: 2rem;
		padding: 0 var(--space-1);
		border: 0;
		border-radius: var(--radius-full);
		background: transparent;
		color: var(--color-text);
		font: inherit;
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		cursor: pointer;
	}
	.day-num:hover {
		background: var(--color-surface-sunken);
	}
	td.today .day-num {
		background: var(--color-accent);
		color: var(--color-accent-contrast);
	}
	.day-events {
		display: grid;
		grid-template-columns: minmax(0, 1fr);
		gap: 2px;
		margin: var(--space-1) 0 0;
		padding: 0;
		list-style: none;
	}
	.chip {
		display: flex;
		align-items: baseline;
		gap: var(--space-1);
		width: 100%;
		min-width: 0;
		min-height: 1.5rem;
		padding: 0 var(--space-2);
		overflow: hidden;
		border: 0;
		border-inline-start: 3px solid var(--tone);
		/* Square on the colour bar's side, so the bar reads as a bar. */
		border-radius: var(--radius-sm);
		border-start-start-radius: 0;
		border-end-start-radius: 0;
		background: transparent;
		color: var(--color-text);
		font: inherit;
		font-size: var(--text-xs);
		line-height: 1.5rem;
		text-align: start;
		cursor: pointer;
	}
	.chip:hover {
		background: var(--tone-bg);
	}
	.chip.all-day {
		background: var(--tone-bg);
		color: var(--tone);
		font-weight: var(--weight-medium);
	}
	.chip .time {
		flex: none;
		color: var(--color-text-muted);
		font-variant-numeric: tabular-nums;
	}
	.chip-title {
		min-width: 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.more {
		min-height: 1.5rem;
		padding: 0 var(--space-2);
		border: 0;
		border-radius: var(--radius-sm);
		background: transparent;
		color: var(--color-text-muted);
		font: inherit;
		font-size: var(--text-xs);
		font-weight: var(--weight-medium);
		cursor: pointer;
	}
	.more:hover {
		color: var(--color-text);
	}
	.month.narrow td {
		height: 3.5rem;
		padding: var(--space-1) 0;
		text-align: center;
		cursor: default;
	}
	.month.narrow th {
		padding: var(--space-2) 0;
		text-align: center;
	}
	.month.narrow .day-num {
		width: 2.75rem;
		height: 2.75rem;
		margin: 0 auto;
	}
	.dots {
		display: flex;
		justify-content: center;
		gap: 3px;
		height: var(--space-2);
	}
	.dot {
		width: 0.375rem;
		height: 0.375rem;
		border-radius: var(--radius-full);
		background: var(--tone);
	}

	/* Agenda */
	.agenda {
		display: grid;
		gap: var(--space-2);
	}
	.agenda-day {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		margin: var(--space-3) 0 0;
		font-family: var(--font-sans);
		font-size: var(--text-sm);
		font-weight: var(--weight-semibold);
		color: var(--color-text-muted);
	}
	.agenda-day:first-child {
		margin-top: 0;
	}
	.agenda-day::first-letter {
		text-transform: uppercase;
	}
	.agenda-day.today {
		color: var(--color-text);
	}
	.today-pill {
		padding: 0 var(--space-2);
		border-radius: var(--radius-full);
		background: var(--color-accent);
		color: var(--color-accent-contrast);
		font-size: var(--text-xs);
		line-height: 1.5rem;
	}
	.rows {
		margin: 0;
		padding: 0;
		list-style: none;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
		box-shadow: var(--shadow-sm);
		overflow: hidden;
	}
	.rows li + li {
		border-top: 1px solid var(--color-border);
	}
	.row {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		width: 100%;
		min-height: 3.5rem;
		padding: var(--space-2) var(--space-4);
		border: 0;
		background: transparent;
		color: var(--color-text);
		font: inherit;
		text-align: start;
		cursor: pointer;
	}
	.row:hover {
		background: color-mix(in srgb, var(--color-surface-sunken) 60%, transparent);
	}
	.when {
		flex: none;
		width: 8.5rem;
		color: var(--color-text-muted);
		font-size: var(--text-sm);
		font-variant-numeric: tabular-nums;
	}
	.bar {
		flex: none;
		align-self: stretch;
		width: var(--space-1);
		border-radius: var(--radius-full);
		background: var(--tone);
	}
	.what {
		display: grid;
		flex: 1;
		min-width: 0;
	}
	.row-title {
		overflow: hidden;
		font-weight: var(--weight-medium);
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.loc {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
		overflow: hidden;
		color: var(--color-text-muted);
		font-size: var(--text-sm);
		white-space: nowrap;
	}
	.repeat {
		display: grid;
		color: var(--color-text-muted);
	}
	.none {
		display: grid;
		justify-items: center;
		gap: var(--space-3);
		padding: var(--space-7) var(--space-5);
		border: 1px dashed var(--color-border-strong);
		border-radius: var(--radius-xl);
		text-align: center;
	}
	.art {
		display: grid;
		place-items: center;
		width: 3.5rem;
		height: 3.5rem;
		border-radius: var(--radius-full) var(--radius-full) var(--radius-md) var(--radius-md);
		background: var(--color-accent-subtle);
		color: var(--color-accent);
	}
	.muted {
		margin: 0;
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}

	/* Calendars */
	.side {
		display: grid;
		gap: var(--space-2);
		justify-items: start;
	}
	.side-title {
		margin: 0;
		font-family: var(--font-sans);
		font-size: var(--text-xs);
		font-weight: var(--weight-medium);
		letter-spacing: 0.08em;
		text-transform: uppercase;
		color: var(--color-text-muted);
	}
	.cals {
		display: grid;
		width: 100%;
		margin: 0;
		padding: 0;
		list-style: none;
	}
	.cals li {
		display: flex;
		align-items: center;
	}
	.cal {
		display: flex;
		flex: 1;
		align-items: center;
		gap: var(--space-3);
		min-width: 0;
		min-height: 2.75rem;
		cursor: pointer;
	}
	.cal input {
		border-color: var(--tone);
	}
	.cal input:checked {
		background: var(--tone);
	}
	.cal input::after {
		border-color: var(--tone-bg);
	}
	.cal-name {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	@media (max-width: 900px) {
		.layout {
			grid-template-columns: minmax(0, 1fr);
		}
	}
	@media (max-width: 600px) {
		.period {
			order: -1;
			flex-basis: 100%;
			margin: 0;
		}
		.chips {
			margin-inline-start: auto;
		}
		.when {
			width: 6.75rem;
			font-size: var(--text-xs);
			white-space: nowrap;
		}
		.row {
			padding-inline: var(--space-3);
		}
	}
</style>
