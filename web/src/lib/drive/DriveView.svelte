<script lang="ts">
	import { resolve } from '$app/paths';
	import { ChevronRight, FolderPlus, Upload as UploadIcon } from '@lucide/svelte';
	import { ClientResponseError } from 'pocketbase';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import { listChildren, pathTo } from './api.js';
	import FileIcon from './FileIcon.svelte';
	import { formatDate, formatSize } from './format.js';
	import { onNodeChange } from './live.js';
	import { compareNodes } from './names.js';
	import NewFolderDialog from './NewFolderDialog.svelte';
	import type { DriveNode } from './types.js';
	import { uploads } from './uploads.svelte.js';

	let { folderId }: { folderId: string } = $props();

	let children = $state<DriveNode[]>([]);
	let path = $state<DriveNode[]>([]);
	let view = $state<'loading' | 'ready' | 'not-found' | 'error'>('loading');
	let newFolderOpen = $state(false);
	let dragDepth = $state(0);
	let fileInput: HTMLInputElement;

	const locale = getLocale();
	const sorted = $derived([...children].sort((a, b) => compareNodes(a, b, locale)));
	const folderName = $derived(path.at(-1)?.name ?? m.drive_root());

	// Load the folder, then follow changes live (other tabs, devices, uploads).
	$effect(() => {
		const id = folderId;
		let cancelled = false;
		view = 'loading';

		Promise.all([listChildren(id), id ? pathTo(id) : Promise.resolve([])])
			.then(([items, chain]) => {
				if (cancelled) return;
				children = items;
				path = chain;
				view = 'ready';
			})
			.catch((err) => {
				if (!cancelled)
					view = err instanceof ClientResponseError && err.status === 404 ? 'not-found' : 'error';
			});

		const stopListening = onNodeChange(({ action, record }) => {
			if (record.id === id && (action === 'delete' || record.trashed_at)) view = 'not-found';
			const inHere = action !== 'delete' && record.parent === id && !record.trashed_at;
			const others = children.filter((c) => c.id !== record.id);
			children = inHere ? [...others, record] : others;
		});

		return () => {
			cancelled = true;
			stopListening();
		};
	});

	function pickFiles() {
		fileInput.click();
	}

	function onPicked(event: Event) {
		const input = event.currentTarget as HTMLInputElement;
		if (input.files?.length) uploads.add(input.files, folderId);
		input.value = '';
	}

	const hasFiles = (e: DragEvent) => e.dataTransfer?.types.includes('Files') ?? false;

	function onDrop(e: DragEvent) {
		e.preventDefault();
		dragDepth = 0;
		const files = [...(e.dataTransfer?.files ?? [])].filter((f) => f.type !== '' || f.size > 0);
		if (files.length) uploads.add(files, folderId);
	}
</script>

<svelte:head>
	<title>{folderName}</title>
</svelte:head>

<div
	class="drive"
	role="region"
	aria-label={folderName}
	ondragenter={(e) => hasFiles(e) && (e.preventDefault(), dragDepth++)}
	ondragover={(e) => hasFiles(e) && e.preventDefault()}
	ondragleave={() => (dragDepth = Math.max(0, dragDepth - 1))}
	ondrop={onDrop}
>
	{#if folderId}
		<nav aria-label={m.breadcrumb_label()} class="crumbs">
			<ol>
				<li>
					<a href={resolve('/(app)')} aria-current={folderId ? undefined : 'page'}
						>{m.drive_root()}</a
					>
				</li>
				{#each path as node, i (node.id)}
					<li>
						<ChevronRight size={16} aria-hidden="true" />
						<a
							href={resolve('/(app)/folders/[id]', { id: node.id })}
							aria-current={i === path.length - 1 ? 'page' : undefined}>{node.name}</a
						>
					</li>
				{/each}
			</ol>
		</nav>
	{/if}

	<div class="head">
		<h1>{folderName}</h1>
		<div class="actions">
			<Button
				variant="secondary"
				onclick={() => (newFolderOpen = true)}
				disabled={view !== 'ready'}
			>
				<FolderPlus size={18} aria-hidden="true" />
				{m.new_folder_button()}
			</Button>
			<Button onclick={pickFiles} disabled={view !== 'ready'}>
				<UploadIcon size={18} aria-hidden="true" />
				{m.upload_button()}
			</Button>
			<input bind:this={fileInput} type="file" multiple hidden onchange={onPicked} />
		</div>
	</div>

	{#if view === 'loading'}
		<p class="muted" aria-busy="true">{m.loading()}</p>
	{:else if view === 'not-found'}
		<Alert tone="info">{m.folder_not_found()}</Alert>
	{:else if view === 'error'}
		<Alert>{m.error_load()}</Alert>
	{:else if sorted.length === 0}
		<section class="empty" aria-labelledby="empty-title">
			<div class="art" aria-hidden="true">
				<div class="sheet back"></div>
				<div class="sheet mid"></div>
				<div class="sheet front"><UploadIcon size={22} /></div>
			</div>
			<h2 id="empty-title">{folderId ? m.folder_empty_title() : m.files_empty_title()}</h2>
			<p>{folderId ? m.folder_empty_body() : m.files_empty_body()}</p>
		</section>
	{:else}
		<table class="list">
			<thead>
				<tr>
					<th scope="col">{m.col_name()}</th>
					<th scope="col" class="num">{m.col_size()}</th>
					<th scope="col" class="date">{m.col_modified()}</th>
				</tr>
			</thead>
			<tbody>
				{#each sorted as node (node.id)}
					<tr>
						<td>
							<div class="name-cell">
								<FileIcon kind={node.kind} mime={node.mime} />
								{#if node.kind === 'folder'}
									<a class="name" href={resolve('/(app)/folders/[id]', { id: node.id })}
										>{node.name}</a
									>
								{:else}
									<span class="name">{node.name}</span>
								{/if}
							</div>
						</td>
						<td class="num muted">{node.kind === 'folder' ? '—' : formatSize(node.size, locale)}</td
						>
						<td class="date muted">{formatDate(node.updated, locale)}</td>
					</tr>
				{/each}
			</tbody>
		</table>
	{/if}

	{#if dragDepth > 0}
		<div class="dropzone" aria-hidden="true">
			<UploadIcon size={28} />
			<p>{m.drop_here({ folder: folderName })}</p>
		</div>
	{/if}
</div>

<NewFolderDialog bind:open={newFolderOpen} parent={folderId} />

<style>
	.drive {
		position: relative;
		min-height: calc(100dvh - 8rem);
	}
	.crumbs ol {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-1);
		margin: 0 0 var(--space-2);
		padding: 0;
		list-style: none;
		font-size: var(--text-sm);
	}
	.crumbs li {
		display: flex;
		align-items: center;
		gap: var(--space-1);
		color: var(--color-text-muted);
	}
	.crumbs a {
		color: var(--color-text-muted);
		text-decoration: none;
		padding: var(--space-1) var(--space-1);
		border-radius: var(--radius-sm);
	}
	.crumbs a:hover {
		color: var(--color-text);
		background: var(--color-surface-sunken);
	}
	.crumbs a[aria-current='page'] {
		color: var(--color-text);
		font-weight: var(--weight-medium);
	}
	.head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		flex-wrap: wrap;
		gap: var(--space-4);
		margin-bottom: var(--space-5);
	}
	h1 {
		font-size: var(--text-2xl);
		letter-spacing: -0.02em;
		overflow-wrap: anywhere;
	}
	.actions {
		display: flex;
		gap: var(--space-2);
	}
	.muted {
		color: var(--color-text-muted);
	}
	.list {
		width: 100%;
		border-collapse: separate;
		border-spacing: 0;
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		overflow: hidden;
	}
	th {
		text-align: left;
		font-size: var(--text-xs);
		font-weight: var(--weight-medium);
		text-transform: uppercase;
		letter-spacing: 0.04em;
		color: var(--color-text-muted);
		padding: var(--space-3) var(--space-4);
		border-bottom: 1px solid var(--color-border);
	}
	td {
		padding: var(--space-2) var(--space-4);
		border-bottom: 1px solid var(--color-border);
		font-size: var(--text-sm);
	}
	tbody tr:last-child td {
		border-bottom: 0;
	}
	tbody tr {
		transition: background var(--duration-fast) var(--ease-standard);
	}
	tbody tr:hover {
		background: var(--color-surface-sunken);
	}
	.num,
	.date {
		width: 9rem;
		white-space: nowrap;
		font-variant-numeric: tabular-nums;
	}
	.num {
		text-align: right;
	}
	.name-cell {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		min-width: 0;
	}
	.name {
		font-size: var(--text-md);
		color: var(--color-text);
		text-decoration: none;
		overflow-wrap: anywhere;
	}
	a.name:hover {
		text-decoration: underline;
	}
	@media (max-width: 600px) {
		.date {
			display: none;
		}
		.num {
			width: 5.5rem;
		}
	}
	.empty {
		display: grid;
		justify-items: center;
		gap: var(--space-2);
		padding: var(--space-8) var(--space-5);
		border: 1.5px dashed var(--color-border-strong);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
		text-align: center;
	}
	.empty h2 {
		font-size: var(--text-lg);
	}
	.empty p {
		margin: 0;
		max-width: 28rem;
		color: var(--color-text-muted);
	}
	.art {
		position: relative;
		width: 5.5rem;
		height: 5rem;
		margin-bottom: var(--space-4);
	}
	.sheet {
		position: absolute;
		inset: 0;
		border-radius: var(--radius-md);
		border: 1px solid var(--color-border);
		background: var(--color-surface-raised);
		box-shadow: var(--shadow-sm);
	}
	.back {
		transform: rotate(-10deg) translate(-10px, 4px);
		background: var(--color-surface-sunken);
	}
	.mid {
		transform: rotate(6deg) translate(8px, 2px);
	}
	.front {
		display: grid;
		place-items: center;
		color: var(--color-accent);
		background: var(--color-accent-subtle);
		border-color: transparent;
		box-shadow: var(--shadow-md);
	}
	.dropzone {
		position: absolute;
		inset: 0;
		z-index: 4;
		display: grid;
		place-content: center;
		justify-items: center;
		gap: var(--space-2);
		border: 2px dashed var(--color-accent);
		border-radius: var(--radius-lg);
		background: color-mix(in srgb, var(--color-accent-subtle) 85%, transparent);
		color: var(--color-accent);
		font-weight: var(--weight-medium);
		pointer-events: none;
	}
	.dropzone p {
		margin: 0;
	}
</style>
