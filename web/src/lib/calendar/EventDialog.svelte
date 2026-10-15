<script lang="ts">
	import { Repeat as RepeatIcon } from '@lucide/svelte';
	import { untrack } from 'svelte';
	import { m } from '#lib/paraglide/messages.js';
	import { pb } from '#lib/pb.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';
	import Select from '#lib/ui/Select.svelte';
	import TextField from '#lib/ui/TextField.svelte';
	import {
		draftFromEvent,
		draftToRecord,
		eventsCol,
		moveStart,
		newDraft,
		validateDraft,
		type CalEvent,
		type Calendar,
		type Draft,
		type DraftError,
		type Ends,
		type Repeat
	} from './calendar.js';

	let {
		open = $bindable(false),
		event,
		day,
		calendars,
		onsaved,
		ondeleted
	}: {
		open?: boolean;
		/** The event to edit, or null to create one on `day`. */
		event: CalEvent | null;
		day: string;
		calendars: Calendar[];
		onsaved: (ev: CalEvent) => void;
		ondeleted: (id: string) => void;
	} = $props();

	const uid = $props.id();
	let draft = $state<Draft>(newDraft('2000-01-01', ''));
	let error = $state<DraftError>(null);
	let failed = $state(false);
	let saving = $state(false);
	let confirming = $state(false);

	// Fresh fields every time the dialog opens.
	$effect(() => {
		if (!open) return;
		untrack(() => {
			draft = event ? draftFromEvent(event) : newDraft(day, calendars[0]?.id ?? '');
			error = null;
			failed = false;
			confirming = false;
		});
	});

	const repeats: { value: Repeat; label: string }[] = [
		{ value: 'none', label: m.calendar_repeat_none() },
		{ value: 'DAILY', label: m.calendar_repeat_daily() },
		{ value: 'WEEKLY', label: m.calendar_repeat_weekly() },
		{ value: 'MONTHLY', label: m.calendar_repeat_monthly() },
		{ value: 'YEARLY', label: m.calendar_repeat_yearly() }
	];
	const endings: { value: Ends; label: string }[] = [
		{ value: 'never', label: m.calendar_ends_never() },
		{ value: 'until', label: m.calendar_ends_until() },
		{ value: 'count', label: m.calendar_ends_count() }
	];
	const messages: Record<Exclude<DraftError, null>, () => string> = {
		title: m.calendar_error_title,
		end: m.calendar_error_end,
		until: m.calendar_error_until,
		count: m.calendar_error_count
	};
	const errorText = (key: DraftError) => (error === key && key ? messages[key]() : null);

	// shortcut: edits and deletes apply to the whole series (no EXDATE / RECURRENCE-ID exceptions);
	// add per-occurrence exceptions with CalDAV (ADR 0028).
	async function save(e: SubmitEvent) {
		e.preventDefault();
		error = validateDraft(draft);
		if (error) return;
		saving = true;
		failed = false;
		try {
			const data = draftToRecord(draft);
			const saved = event
				? await eventsCol().update(event.id, data)
				: await eventsCol().create({ ...data, owner: pb.authStore.record?.id });
			onsaved(saved);
			open = false;
		} catch {
			failed = true;
		} finally {
			saving = false;
		}
	}

	async function remove() {
		if (!event) return;
		saving = true;
		failed = false;
		try {
			await eventsCol().delete(event.id);
			ondeleted(event.id);
			open = false;
		} catch {
			failed = true;
		} finally {
			saving = false;
		}
	}
</script>

<Dialog bind:open title={event ? m.calendar_edit_event() : m.calendar_new_event()}>
	{#if confirming && event}
		<p class="confirm">
			{event.rrule
				? m.calendar_delete_series_body({ name: event.title })
				: m.calendar_delete_event_body({ name: event.title })}
		</p>
		{#if failed}<Alert>{m.error_unexpected()}</Alert>{/if}
		<div class="actions">
			<Button variant="ghost" onclick={() => (confirming = false)}>{m.cancel_button()}</Button>
			<Button variant="danger" loading={saving} onclick={remove}>{m.calendar_delete_event()}</Button
			>
		</div>
	{:else}
		<form class="form" onsubmit={save} novalidate>
			<TextField
				label={m.calendar_event_title()}
				bind:value={draft.title}
				maxlength={200}
				autocomplete="off"
				required
				error={errorText('title')}
			/>
			<label class="check">
				<input type="checkbox" bind:checked={draft.allDay} />
				{m.calendar_all_day()}
			</label>
			<div class="pair" class:single={draft.allDay}>
				<TextField
					label={m.calendar_start_date()}
					type="date"
					required
					value={draft.startDay}
					oninput={(e) => (draft = moveStart(draft, e.currentTarget.value, draft.startTime))}
				/>
				{#if !draft.allDay}
					<TextField
						label={m.calendar_start_time()}
						type="time"
						required
						value={draft.startTime}
						oninput={(e) => (draft = moveStart(draft, draft.startDay, e.currentTarget.value))}
					/>
				{/if}
			</div>
			<div class="pair" class:single={draft.allDay}>
				<TextField
					label={m.calendar_end_date()}
					type="date"
					required
					bind:value={draft.endDay}
					error={errorText('end')}
				/>
				{#if !draft.allDay}
					<TextField
						label={m.calendar_end_time()}
						type="time"
						required
						bind:value={draft.endTime}
					/>
				{/if}
			</div>
			{#if calendars.length > 1}
				<div class="field">
					<span class="label" id="cal-{uid}">{m.calendar_calendar()}</span>
					<Select
						labelledby="cal-{uid}"
						bind:value={draft.calendar}
						options={calendars.map((c) => ({ value: c.id, label: c.name }))}
					/>
				</div>
			{/if}
			<div class="field">
				<span class="label" id="repeat-{uid}">{m.calendar_repeat()}</span>
				<Select labelledby="repeat-{uid}" bind:value={draft.repeat} options={repeats} />
			</div>
			{#if draft.repeat !== 'none'}
				<div class="pair">
					<div class="field">
						<span class="label" id="ends-{uid}">{m.calendar_repeat_ends()}</span>
						<Select labelledby="ends-{uid}" bind:value={draft.ends} options={endings} />
					</div>
					{#if draft.ends === 'until'}
						<TextField
							label={m.calendar_until()}
							type="date"
							bind:value={draft.until}
							error={errorText('until')}
						/>
					{:else if draft.ends === 'count'}
						<TextField
							label={m.calendar_count()}
							type="number"
							min="1"
							max="999"
							value={String(draft.count)}
							oninput={(e) => (draft.count = Number(e.currentTarget.value))}
							error={errorText('count')}
						/>
					{/if}
				</div>
				{#if event?.rrule}
					<p class="note"><RepeatIcon size={16} aria-hidden="true" />{m.calendar_series_note()}</p>
				{/if}
			{/if}
			<TextField
				label={m.calendar_location()}
				bind:value={draft.location}
				maxlength={500}
				autocomplete="off"
			/>
			<div class="field">
				<label class="label" for="desc-{uid}">{m.calendar_description()}</label>
				<textarea id="desc-{uid}" bind:value={draft.description} maxlength="10000" rows="3"
				></textarea>
			</div>
			{#if failed}<Alert>{m.error_unexpected()}</Alert>{/if}
			<div class="actions">
				{#if event}
					<span class="delete">
						<Button variant="ghost" onclick={() => (confirming = true)}
							>{m.calendar_delete_event()}</Button
						>
					</span>
				{/if}
				<Button variant="ghost" onclick={() => (open = false)}>{m.cancel_button()}</Button>
				<Button type="submit" loading={saving}>{m.save_button()}</Button>
			</div>
		</form>
	{/if}
</Dialog>

<style>
	.form {
		display: grid;
		gap: var(--space-4);
	}
	.pair {
		display: grid;
		grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
		gap: var(--space-3);
		align-items: start;
	}
	.pair.single {
		grid-template-columns: minmax(0, 1fr);
	}
	.field {
		display: grid;
		gap: var(--space-2);
		min-width: 0;
	}
	.label {
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
	}
	.check {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		justify-self: start;
		min-height: 2.75rem;
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		cursor: pointer;
	}
	textarea {
		width: 100%;
		min-height: 5rem;
		padding: var(--space-2) var(--space-3);
		border: 1px solid var(--color-border-strong);
		border-radius: var(--radius-md);
		background: var(--color-surface);
		color: var(--color-text);
		font: inherit;
		resize: vertical;
	}
	textarea:focus-visible {
		outline: 2px solid var(--color-focus);
		outline-offset: 1px;
	}
	.note {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		margin: 0;
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.note :global(svg) {
		flex: none;
	}
	.confirm {
		margin: 0;
	}
	.actions {
		display: flex;
		flex-wrap: wrap;
		justify-content: flex-end;
		gap: var(--space-2);
		margin-top: var(--space-2);
	}
	.delete {
		margin-inline-end: auto;
	}
	.delete :global(.btn) {
		color: var(--color-danger);
	}
</style>
