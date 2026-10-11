<script lang="ts">
	import { ChevronRight, Folder } from '@lucide/svelte';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';
	import { listFolders, pathTo } from './api.js';
	import { compareNodes } from './names.js';
	import type { DriveNode } from './types.js';

	let {
		open = $bindable(false),
		items,
		start,
		onmove
	}: {
		open?: boolean;
		items: DriveNode[];
		start: string;
		onmove: (destination: string, destinationName: string) => void;
	} = $props();

	let browse = $state('');
	let path = $state<DriveNode[]>([]);
	let folders = $state<DriveNode[]>([]);
	let loading = $state(false);

	const moving = $derived(new Set(items.map((i) => i.id)));
	const title = $derived(
		items.length === 1
			? m.move_title_one({ name: items[0]?.name ?? '' })
			: m.move_title_many({ count: items.length })
	);
	// Moving into the current parent of every item would be a no-op.
	const noop = $derived(items.every((i) => i.parent === browse));

	$effect(() => {
		if (open) browse = start;
	});

	$effect(() => {
		if (!open) return;
		const id = browse;
		loading = true;
		Promise.all([listFolders(id), id ? pathTo(id) : Promise.resolve([])]).then(([list, chain]) => {
			if (browse !== id) return;
			folders = list.sort((a, b) => compareNodes(a, b, getLocale()));
			path = chain;
			loading = false;
		});
	});

	function confirm() {
		open = false;
		onmove(browse, path.at(-1)?.name ?? m.drive_root());
	}
</script>

<Dialog bind:open {title}>
	<nav class="crumbs" aria-label={m.breadcrumb_label()}>
		<button
			class="crumb"
			aria-current={browse === '' ? 'location' : undefined}
			onclick={() => (browse = '')}
		>
			{m.drive_root()}
		</button>
		{#each path as node (node.id)}
			<ChevronRight size={14} aria-hidden="true" />
			<button
				class="crumb"
				aria-current={browse === node.id ? 'location' : undefined}
				onclick={() => (browse = node.id)}>{node.name}</button
			>
		{/each}
	</nav>

	<ul class="folders" aria-busy={loading}>
		{#each folders as folder (folder.id)}
			<li>
				<button
					class="folder"
					disabled={moving.has(folder.id)}
					onclick={() => (browse = folder.id)}
				>
					<Folder size={18} aria-hidden="true" />
					<span>{folder.name}</span>
					<ChevronRight size={16} aria-hidden="true" class="chev" />
				</button>
			</li>
		{:else}
			{#if !loading}<li class="none">{m.move_no_subfolders()}</li>{/if}
		{/each}
	</ul>

	<div class="actions">
		<Button variant="ghost" onclick={() => (open = false)}>{m.cancel_button()}</Button>
		<Button onclick={confirm} disabled={loading || noop}>{m.move_here()}</Button>
	</div>
</Dialog>

<style>
	.crumbs {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-1);
		font-size: var(--text-sm);
		color: var(--color-text-muted);
	}
	.crumb {
		border: 0;
		background: none;
		font: inherit;
		color: var(--color-text-muted);
		padding: var(--space-1);
		border-radius: var(--radius-sm);
		cursor: pointer;
		min-height: 2rem;
	}
	.crumb:hover {
		background: var(--color-surface-sunken);
		color: var(--color-text);
	}
	.crumb[aria-current='location'] {
		color: var(--color-text);
		font-weight: var(--weight-medium);
	}
	.folders {
		list-style: none;
		margin: 0;
		padding: var(--space-1);
		min-height: 12rem;
		max-height: 18rem;
		overflow-y: auto;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-md);
		background: var(--color-surface);
	}
	.folder {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		width: 100%;
		min-height: 2.75rem;
		padding: 0 var(--space-3);
		border: 0;
		border-radius: var(--radius-sm);
		background: transparent;
		font: inherit;
		color: var(--color-text);
		text-align: left;
		cursor: pointer;
	}
	.folder:hover:not(:disabled) {
		background: var(--color-surface-sunken);
	}
	.folder:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}
	.folder span {
		flex: 1;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.folder :global(.chev) {
		color: var(--color-text-muted);
	}
	.none {
		padding: var(--space-4);
		text-align: center;
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.actions {
		display: flex;
		justify-content: flex-end;
		gap: var(--space-2);
	}
</style>
