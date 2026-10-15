<script lang="ts">
	import { Check } from '@lucide/svelte';
	import { ClientResponseError } from 'pocketbase';
	import { untrack } from 'svelte';
	import { m } from '#lib/paraglide/messages.js';
	import { pb } from '#lib/pb.js';
	import { TAG_COLORS, type TagColor } from '#lib/tags/tags.svelte.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';
	import TextField from '#lib/ui/TextField.svelte';
	import { calendarsCol, type Calendar } from './calendar.js';

	let {
		open = $bindable(false),
		calendar,
		canDelete,
		onsaved,
		ondeleted
	}: {
		open?: boolean;
		/** The calendar to edit, or null to create one. */
		calendar: Calendar | null;
		canDelete: boolean;
		onsaved: (cal: Calendar) => void;
		ondeleted: (id: string) => void;
	} = $props();

	const colorNames: Record<TagColor, () => string> = {
		gray: m.tag_color_gray,
		red: m.tag_color_red,
		orange: m.tag_color_orange,
		yellow: m.tag_color_yellow,
		green: m.tag_color_green,
		teal: m.tag_color_teal,
		blue: m.tag_color_blue,
		violet: m.tag_color_violet,
		pink: m.tag_color_pink
	};

	let name = $state('');
	let color = $state<TagColor>('blue');
	let error = $state('');
	let saving = $state(false);
	let confirming = $state(false);

	$effect(() => {
		if (!open) return;
		untrack(() => {
			name = calendar?.name ?? '';
			color = calendar?.color ?? 'blue';
			error = '';
			confirming = false;
		});
	});

	async function save(e: SubmitEvent) {
		e.preventDefault();
		if (!name.trim()) return;
		saving = true;
		error = '';
		try {
			const data = { name: name.trim(), color };
			onsaved(
				calendar
					? await calendarsCol().update(calendar.id, data)
					: await calendarsCol().create({ ...data, owner: pb.authStore.record?.id })
			);
			open = false;
		} catch (err) {
			error =
				err instanceof ClientResponseError && err.status === 400
					? m.calendar_name_taken()
					: m.error_unexpected();
		} finally {
			saving = false;
		}
	}

	async function remove() {
		if (!calendar) return;
		saving = true;
		try {
			await calendarsCol().delete(calendar.id);
			ondeleted(calendar.id);
			open = false;
		} catch {
			error = m.error_unexpected();
		} finally {
			saving = false;
		}
	}
</script>

<Dialog bind:open title={calendar ? m.calendar_edit_calendar() : m.calendar_new_calendar()}>
	{#if confirming && calendar}
		<p class="confirm">{m.calendar_delete_calendar_body({ name: calendar.name })}</p>
		{#if error}<Alert>{error}</Alert>{/if}
		<div class="actions">
			<Button variant="ghost" onclick={() => (confirming = false)}>{m.cancel_button()}</Button>
			<Button variant="danger" loading={saving} onclick={remove}
				>{m.calendar_delete_calendar()}</Button
			>
		</div>
	{:else}
		<form class="form" onsubmit={save}>
			<TextField
				label={m.calendar_name()}
				bind:value={name}
				maxlength={60}
				required
				autocomplete="off"
			/>
			<div class="swatches" role="radiogroup" aria-label={m.calendar_color()}>
				{#each TAG_COLORS as c (c)}
					<button
						type="button"
						role="radio"
						aria-checked={color === c}
						aria-label={colorNames[c]()}
						class="swatch"
						style="--tone: var(--color-tag-{c}); --tone-bg: var(--color-tag-{c}-bg)"
						onclick={() => (color = c)}
					>
						{#if color === c}<Check size={14} aria-hidden="true" />{/if}
					</button>
				{/each}
			</div>
			{#if error}<Alert>{error}</Alert>{/if}
			<div class="actions">
				{#if calendar && canDelete}
					<span class="delete">
						<Button variant="ghost" onclick={() => (confirming = true)}
							>{m.calendar_delete_calendar()}</Button
						>
					</span>
				{/if}
				<Button variant="ghost" onclick={() => (open = false)}>{m.cancel_button()}</Button>
				<Button type="submit" loading={saving} disabled={!name.trim()}
					>{calendar ? m.save_button() : m.create_button()}</Button
				>
			</div>
		</form>
	{/if}
</Dialog>

<style>
	.form {
		display: grid;
		gap: var(--space-4);
	}
	.swatches {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
	}
	.swatch {
		display: grid;
		place-items: center;
		width: 2rem;
		height: 2rem;
		padding: 0;
		border: 0;
		border-radius: var(--radius-full);
		background: var(--tone);
		color: var(--tone-bg);
		cursor: pointer;
	}
	.swatch[aria-checked='true'] {
		box-shadow:
			0 0 0 2px var(--color-surface-raised),
			0 0 0 4px var(--color-text-muted);
	}
	.swatch:focus-visible {
		outline: 2px solid var(--color-focus);
		outline-offset: 3px;
	}
	.confirm {
		margin: 0;
	}
	.actions {
		display: flex;
		flex-wrap: wrap;
		justify-content: flex-end;
		gap: var(--space-2);
	}
	.delete {
		margin-inline-end: auto;
	}
	.delete :global(.btn) {
		color: var(--color-danger);
	}
</style>
