<script lang="ts">
	import { ClientResponseError } from 'pocketbase';
	import { Check, Pencil, Plus, Trash2 } from '@lucide/svelte';
	import type { DriveNode } from '#lib/drive/types.js';
	import { m } from '#lib/paraglide/messages.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';
	import TagChip from './TagChip.svelte';
	import { nextColor, setNodeTags, TAG_COLORS, tags, type TagColor } from './tags.svelte.js';

	let {
		open = $bindable(false),
		node,
		onsaved
	}: {
		open?: boolean;
		node: (DriveNode & { tags?: string[] }) | null;
		onsaved?: (tagIds: string[]) => void;
	} = $props();

	const MAX = 20;
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

	let selected = $state<string[]>([]);
	let newName = $state('');
	let newColor = $state<TagColor>('blue');
	let editing = $state<string | null>(null);
	let editName = $state('');
	let editColor = $state<TagColor>('blue');
	let error = $state('');
	let saving = $state(false);

	$effect(() => {
		if (!open || !node) return;
		selected = [...(node.tags ?? [])];
		error = '';
		editing = null;
		newName = '';
		tags.load().then(() => (newColor = nextColor(tags.items.length)));
	});

	const message = (err: unknown) => {
		if (err instanceof ClientResponseError && err.response?.data?.name) return m.tag_name_taken();
		return m.error_unexpected();
	};

	function toggle(id: string) {
		selected = selected.includes(id) ? selected.filter((x) => x !== id) : [...selected, id];
	}

	async function add(event: SubmitEvent) {
		event.preventDefault();
		const name = newName.trim();
		if (!name) return;
		error = '';
		try {
			const tag = await tags.create(name, newColor);
			if (selected.length < MAX) selected = [...selected, tag.id];
			newName = '';
			newColor = nextColor(tags.items.length);
		} catch (err) {
			error = message(err);
		}
	}

	function startEdit(id: string) {
		const t = tags.byId.get(id);
		if (!t) return;
		editing = id;
		editName = t.name;
		editColor = t.color;
	}

	async function saveEdit() {
		if (!editing || !editName.trim()) return;
		error = '';
		try {
			await tags.update(editing, { name: editName.trim(), color: editColor });
			editing = null;
		} catch (err) {
			error = message(err);
		}
	}

	async function removeTag(id: string) {
		if (!confirm(m.tag_delete_confirm({ name: tags.byId.get(id)?.name ?? '' }))) return;
		error = '';
		try {
			await tags.remove(id);
			selected = selected.filter((x) => x !== id);
			editing = null;
		} catch {
			error = m.error_unexpected();
		}
	}

	async function save() {
		if (!node) return;
		saving = true;
		error = '';
		try {
			await setNodeTags(node.id, selected);
			onsaved?.(selected);
			open = false;
		} catch {
			error = m.error_unexpected();
		} finally {
			saving = false;
		}
	}
</script>

{#snippet swatches(value: TagColor, set: (c: TagColor) => void, label: string)}
	<div class="swatches" role="radiogroup" aria-label={label}>
		{#each TAG_COLORS as c (c)}
			<button
				type="button"
				role="radio"
				aria-checked={value === c}
				aria-label={colorNames[c]()}
				class="swatch {c}"
				onclick={() => set(c)}
			>
				{#if value === c}<Check size={14} aria-hidden="true" />{/if}
			</button>
		{/each}
	</div>
{/snippet}

<Dialog bind:open title={m.tags_title({ name: node?.name ?? '' })}>
	{#if !tags.loaded}
		<p class="muted">{m.loading()}</p>
	{:else}
		{#if tags.items.length === 0}
			<p class="muted">{m.tags_empty()}</p>
		{:else}
			<ul class="list" aria-label={m.tags_label()}>
				{#each tags.items as t (t.id)}
					<li>
						{#if editing === t.id}
							<div class="edit">
								<input
									class="input"
									bind:value={editName}
									maxlength="40"
									aria-label={m.tag_name()}
									onkeydown={(e) => e.key === 'Enter' && (e.preventDefault(), saveEdit())}
								/>
								{@render swatches(editColor, (c) => (editColor = c), m.tag_color())}
								<div class="row-actions">
									<Button variant="ghost" onclick={() => removeTag(t.id)}>
										<Trash2 size={16} aria-hidden="true" />{m.tag_delete()}
									</Button>
									<Button variant="secondary" onclick={saveEdit}>{m.save_button()}</Button>
								</div>
							</div>
						{:else}
							<label class="pick">
								<input
									type="checkbox"
									checked={selected.includes(t.id)}
									disabled={!selected.includes(t.id) && selected.length >= MAX}
									onchange={() => toggle(t.id)}
								/>
								<TagChip tag={t} size="md" />
							</label>
							<button
								class="icon-btn"
								aria-label={m.tag_edit({ name: t.name })}
								onclick={() => startEdit(t.id)}
							>
								<Pencil size={16} aria-hidden="true" />
							</button>
						{/if}
					</li>
				{/each}
			</ul>
		{/if}

		<form class="new" onsubmit={add}>
			<div class="new-row">
				<input
					class="input"
					bind:value={newName}
					maxlength="40"
					placeholder={m.tag_new_placeholder()}
					aria-label={m.tag_new()}
				/>
				<Button type="submit" variant="secondary" disabled={!newName.trim()}>
					<Plus size={16} aria-hidden="true" />{m.tag_add()}
				</Button>
			</div>
			{@render swatches(newColor, (c) => (newColor = c), m.tag_new_color())}
		</form>

		{#if error}<Alert>{error}</Alert>{/if}

		<div class="actions">
			<Button variant="ghost" onclick={() => (open = false)}>{m.cancel_button()}</Button>
			<Button onclick={save} loading={saving}>{m.save_button()}</Button>
		</div>
	{/if}
</Dialog>

<style>
	.muted {
		margin: 0;
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.list {
		display: grid;
		gap: 2px;
		max-height: 16rem;
		margin: 0;
		padding: 0;
		overflow-y: auto;
		list-style: none;
	}
	.list li {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-2);
		border-radius: var(--radius-md);
	}
	.list li:hover {
		background: var(--color-surface-sunken);
	}
	.pick {
		display: flex;
		flex: 1;
		align-items: center;
		gap: var(--space-3);
		min-height: 2.75rem;
		padding: 0 var(--space-2);
		cursor: pointer;
	}
	.edit {
		display: grid;
		flex: 1;
		gap: var(--space-2);
		padding: var(--space-2);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-md);
		background: var(--color-surface);
	}
	.row-actions {
		display: flex;
		justify-content: space-between;
		gap: var(--space-2);
	}
	.input {
		flex: 1;
		min-width: 0;
		min-height: 2.75rem;
		padding: 0 var(--space-3);
		border: 1px solid var(--color-border-strong);
		border-radius: var(--radius-md);
		background: var(--color-surface);
		color: var(--color-text);
		font: inherit;
		font-size: var(--text-sm);
	}
	.input:focus-visible {
		outline: 2px solid var(--color-focus);
		outline-offset: 1px;
	}
	.new {
		display: grid;
		gap: var(--space-2);
		padding-top: var(--space-3);
		border-top: 1px solid var(--color-border);
	}
	.new-row {
		display: flex;
		gap: var(--space-2);
	}
	.swatches {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
	}
	.swatch {
		display: grid;
		place-items: center;
		width: 1.75rem;
		height: 1.75rem;
		padding: 0;
		border: 0;
		border-radius: var(--radius-full);
		cursor: pointer;
	}
	.swatch[aria-checked='true'] {
		box-shadow:
			0 0 0 2px var(--color-surface-raised),
			0 0 0 4px var(--color-text-muted);
	}
	.swatch:focus-visible {
		outline: 2px solid var(--color-focus);
		outline-offset: 2px;
	}
	.swatch.gray {
		background: var(--color-tag-gray);
		color: var(--color-tag-gray-bg);
	}
	.swatch.red {
		background: var(--color-tag-red);
		color: var(--color-tag-red-bg);
	}
	.swatch.orange {
		background: var(--color-tag-orange);
		color: var(--color-tag-orange-bg);
	}
	.swatch.yellow {
		background: var(--color-tag-yellow);
		color: var(--color-tag-yellow-bg);
	}
	.swatch.green {
		background: var(--color-tag-green);
		color: var(--color-tag-green-bg);
	}
	.swatch.teal {
		background: var(--color-tag-teal);
		color: var(--color-tag-teal-bg);
	}
	.swatch.blue {
		background: var(--color-tag-blue);
		color: var(--color-tag-blue-bg);
	}
	.swatch.violet {
		background: var(--color-tag-violet);
		color: var(--color-tag-violet-bg);
	}
	.swatch.pink {
		background: var(--color-tag-pink);
		color: var(--color-tag-pink-bg);
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
		background: var(--color-surface);
		color: var(--color-text);
	}
	.actions {
		display: flex;
		justify-content: flex-end;
		gap: var(--space-2);
	}
</style>
