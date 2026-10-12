<script lang="ts">
	import { resolve } from '$app/paths';
	import {
		ChevronRight,
		Download,
		FolderInput,
		FolderPlus,
		LayoutGrid,
		Link,
		List,
		Pencil,
		Trash2,
		Upload as UploadIcon,
		X
	} from '@lucide/svelte';
	import { ClientResponseError, type RecordSubscription } from 'pocketbase';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import ActionsMenu from '#lib/ui/ActionsMenu.svelte';
	import { downloadNode, forEachNode, listChildren, moveNode, pathTo, trashNode } from './api.js';
	import MoveDialog from './MoveDialog.svelte';
	import { Selection } from './selection.svelte.js';
	import { previewKind } from './files.js';
	import Thumb from './Thumb.svelte';
	import Viewer from './Viewer.svelte';
	import ShareDialog from '#lib/shares/ShareDialog.svelte';
	import { formatDate, formatSize } from './format.js';
	import { onNodeChange } from './live.js';
	import { compareNodes } from './names.js';
	import NewFolderDialog from './NewFolderDialog.svelte';
	import RenameDialog from './RenameDialog.svelte';
	import type { DriveNode } from './types.js';
	import { uploads } from './uploads.svelte.js';

	let { folderId }: { folderId: string } = $props();

	let children = $state<DriveNode[]>([]);
	let path = $state<DriveNode[]>([]);
	let view = $state<'loading' | 'ready' | 'not-found' | 'error'>('loading');
	let newFolderOpen = $state(false);
	let renaming = $state<DriveNode | null>(null);
	let actionError = $state<string | null>(null);
	let announcement = $state('');
	let moveOpen = $state(false);
	let moveItems = $state<DriveNode[]>([]);
	let dropTarget = $state<string | null>(null);
	const selection = new Selection();
	let viewerIndex = $state(-1);
	let sharing = $state<DriveNode | null>(null);

	type Layout = 'list' | 'grid';
	const LAYOUT_KEY = 'alcove-drive-layout';
	let layout = $state<Layout>(readLayout());

	function readLayout(): Layout {
		try {
			return localStorage.getItem(LAYOUT_KEY) === 'grid' ? 'grid' : 'list';
		} catch {
			return 'list';
		}
	}

	function setLayout(value: Layout) {
		layout = value;
		try {
			localStorage.setItem(LAYOUT_KEY, value);
		} catch {
			// Private mode: keep it for this session only.
		}
	}
	let dragDepth = $state(0);
	let fileInput: HTMLInputElement;

	const locale = getLocale();
	const sorted = $derived([...children].sort((a, b) => compareNodes(a, b, locale)));
	const folderName = $derived(path.at(-1)?.name ?? m.drive_root());
	const order = $derived(sorted.map((n) => n.id));
	const selected = $derived(sorted.filter((n) => selection.has(n.id)));
	const allSelected = $derived(sorted.length > 0 && selection.size === sorted.length);
	const files = $derived(sorted.filter((n) => n.kind === 'file'));

	/** Opens the viewer for previewable files, downloads the others. */
	function open(node: DriveNode) {
		if (previewKind(node)) viewerIndex = files.indexOf(node);
		else download(node);
	}

	// Keep the selection in sync with what is visible (live moves, trash, …).
	$effect(() => selection.retain(order));

	// Load the folder, then follow changes live (other tabs, devices, uploads).
	$effect(() => {
		const id = folderId;
		let cancelled = false;
		view = 'loading';

		// Live events that arrive while the listing loads are replayed on top of
		// it; otherwise a file uploaded during the load would be overwritten.
		let buffered: RecordSubscription<DriveNode>[] | null = [];

		const apply = ({ action, record }: RecordSubscription<DriveNode>) => {
			if (record.id === id && (action === 'delete' || record.trashed_at)) view = 'not-found';
			const inHere = action !== 'delete' && record.parent === id && !record.trashed_at;
			const others = children.filter((c) => c.id !== record.id);
			children = inHere ? [...others, record] : others;
		};

		Promise.all([listChildren(id), id ? pathTo(id) : Promise.resolve([])])
			.then(([items, chain]) => {
				if (cancelled) return;
				children = items;
				path = chain;
				view = 'ready';
				buffered?.forEach(apply);
				buffered = null;
			})
			.catch((err) => {
				if (!cancelled)
					view = err instanceof ClientResponseError && err.status === 404 ? 'not-found' : 'error';
			});

		const stopListening = onNodeChange((event) => (buffered ? buffered.push(event) : apply(event)));

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

	async function download(node: DriveNode) {
		actionError = null;
		try {
			await downloadNode(node);
		} catch {
			actionError = m.error_download();
		}
	}

	async function trash(items: DriveNode[]) {
		actionError = null;
		const failed = await forEachNode(
			items.map((n) => n.id),
			trashNode
		); // live updates remove the rows
		if (failed.length)
			actionError = m.trash_partial({ failed: failed.length, total: items.length });
	}

	function openMove(items: DriveNode[]) {
		moveItems = items;
		moveOpen = true;
	}

	async function move(items: DriveNode[], destination: string, destinationName: string) {
		actionError = null;
		const ids = items
			.filter((n) => n.id !== destination && n.parent !== destination)
			.map((n) => n.id);
		if (!ids.length) return;
		const failed = await forEachNode(ids, (id) => moveNode(id, destination));
		if (failed.length) actionError = m.move_partial({ failed: failed.length, total: ids.length });
		const moved = ids.length - failed.length;
		if (moved) announcement = m.moved_announce({ count: moved, folder: destinationName });
	}

	// Internal drag & drop: rows carry node ids; folders and breadcrumbs accept them.
	const DRAG_TYPE = 'application/x-alcove-nodes';
	let dragging: DriveNode[] = [];

	function onRowDragStart(e: DragEvent, node: DriveNode) {
		dragging = selection.has(node.id) ? selected : [node];
		e.dataTransfer?.setData(DRAG_TYPE, dragging.map((n) => n.id).join(','));
		if (e.dataTransfer) e.dataTransfer.effectAllowed = 'move';
	}

	const isNodeDrag = (e: DragEvent) => e.dataTransfer?.types.includes(DRAG_TYPE) ?? false;

	function onTargetOver(e: DragEvent, targetId: string) {
		if (!isNodeDrag(e) || dragging.some((n) => n.id === targetId)) return;
		e.preventDefault();
		dropTarget = targetId;
	}

	function onTargetDrop(e: DragEvent, targetId: string, targetName: string) {
		if (!isNodeDrag(e)) return;
		e.preventDefault();
		e.stopPropagation();
		dropTarget = null;
		const items = dragging;
		dragging = [];
		move(items, targetId, targetName);
	}

	function actionsFor(node: DriveNode) {
		return [
			...(node.kind === 'file'
				? [{ label: m.action_download(), icon: Download, onselect: () => download(node) }]
				: []),
			{ label: m.action_share(), icon: Link, onselect: () => (sharing = node) },
			{ label: m.action_rename(), icon: Pencil, onselect: () => (renaming = node) },
			{ label: m.action_move(), icon: FolderInput, onselect: () => openMove([node]) },
			{ label: m.action_trash(), icon: Trash2, danger: true, onselect: () => trash([node]) }
		];
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
					<a
						href={resolve('/(app)')}
						class:drop={dropTarget === ''}
						ondragover={(e) => onTargetOver(e, '')}
						ondragleave={() => (dropTarget = null)}
						ondrop={(e) => onTargetDrop(e, '', m.drive_root())}>{m.drive_root()}</a
					>
				</li>
				{#each path as node, i (node.id)}
					<li>
						<ChevronRight size={16} aria-hidden="true" />
						<a
							href={resolve('/(app)/folders/[id]', { id: node.id })}
							aria-current={i === path.length - 1 ? 'page' : undefined}
							class:drop={dropTarget === node.id}
							ondragover={(e) => onTargetOver(e, node.id)}
							ondragleave={() => (dropTarget = null)}
							ondrop={(e) => onTargetDrop(e, node.id, node.name)}>{node.name}</a
						>
					</li>
				{/each}
			</ol>
		</nav>
	{/if}

	<div class="head">
		<h1>{folderName}</h1>
		{#if selection.size > 0}
			<div class="selbar" role="toolbar" aria-label={m.selected_count({ count: selection.size })}>
				<span class="count">{m.selected_count({ count: selection.size })}</span>
				<Button variant="secondary" onclick={() => openMove(selected)}>
					<FolderInput size={18} aria-hidden="true" />
					{m.action_move()}
				</Button>
				<Button variant="secondary" onclick={() => trash(selected)}>
					<Trash2 size={18} aria-hidden="true" />
					{m.action_trash()}
				</Button>
				<button class="icon-btn" aria-label={m.clear_selection()} onclick={() => selection.clear()}>
					<X size={18} aria-hidden="true" />
				</button>
			</div>
		{:else}
			<div class="actions">
				<div class="segmented" role="radiogroup" aria-label={m.view_mode()}>
					<button
						role="radio"
						aria-checked={layout === 'list'}
						aria-label={m.view_list()}
						title={m.view_list()}
						onclick={() => setLayout('list')}><List size={18} aria-hidden="true" /></button
					>
					<button
						role="radio"
						aria-checked={layout === 'grid'}
						aria-label={m.view_grid()}
						title={m.view_grid()}
						onclick={() => setLayout('grid')}><LayoutGrid size={18} aria-hidden="true" /></button
					>
				</div>
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
			</div>
		{/if}
		<input bind:this={fileInput} type="file" multiple hidden onchange={onPicked} />
	</div>

	{#if actionError}<div class="action-error"><Alert>{actionError}</Alert></div>{/if}

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
		{#if layout === 'grid'}
			<ul class="grid" aria-label={folderName}>
				{#each sorted as node (node.id)}
					<li
						class="tile"
						class:selected={selection.has(node.id)}
						class:drop={dropTarget === node.id}
						draggable="true"
						ondragstart={(e) => onRowDragStart(e, node)}
						ondragend={() => ((dragging = []), (dropTarget = null))}
						ondragover={node.kind === 'folder' ? (e) => onTargetOver(e, node.id) : undefined}
						ondragleave={node.kind === 'folder' ? () => (dropTarget = null) : undefined}
						ondrop={node.kind === 'folder' ? (e) => onTargetDrop(e, node.id, node.name) : undefined}
					>
						<div class="preview" class:folder={node.kind === 'folder'}>
							<Thumb {node} size="320x320" iconSize={36} />
						</div>
						<div class="meta">
							{#if node.kind === 'folder'}
								<a class="tile-name" href={resolve('/(app)/folders/[id]', { id: node.id })}
									>{node.name}</a
								>
							{:else}
								<button class="tile-name as-link" onclick={() => open(node)}>{node.name}</button>
							{/if}
							<span class="muted small"
								>{node.kind === 'folder' ? m.kind_folder() : formatSize(node.size, locale)}</span
							>
						</div>
						<input
							class="tile-check"
							type="checkbox"
							aria-label={m.select_item({ name: node.name })}
							checked={selection.has(node.id)}
							onclick={(e) => selection.toggle(node.id, order, e.shiftKey)}
						/>
						<div class="tile-menu">
							<ActionsMenu label={m.actions_for({ name: node.name })} actions={actionsFor(node)} />
						</div>
					</li>
				{/each}
			</ul>
		{:else}
			<table class="list">
				<thead>
					<tr>
						<th scope="col" class="check">
							<input
								type="checkbox"
								aria-label={m.select_all()}
								checked={allSelected}
								indeterminate={selection.size > 0 && !allSelected}
								onchange={(e) => selection.setAll(order, e.currentTarget.checked)}
							/>
						</th>
						<th scope="col">{m.col_name()}</th>
						<th scope="col" class="num">{m.col_size()}</th>
						<th scope="col" class="date">{m.col_modified()}</th>
						<th scope="col" class="act"
							><span class="visually-hidden">{m.actions_for({ name: '' })}</span></th
						>
					</tr>
				</thead>
				<tbody>
					{#each sorted as node (node.id)}
						<tr
							class:selected={selection.has(node.id)}
							class:drop={dropTarget === node.id}
							draggable="true"
							ondragstart={(e) => onRowDragStart(e, node)}
							ondragend={() => ((dragging = []), (dropTarget = null))}
							ondragover={node.kind === 'folder' ? (e) => onTargetOver(e, node.id) : undefined}
							ondragleave={node.kind === 'folder' ? () => (dropTarget = null) : undefined}
							ondrop={node.kind === 'folder'
								? (e) => onTargetDrop(e, node.id, node.name)
								: undefined}
						>
							<td class="check">
								<input
									type="checkbox"
									aria-label={m.select_item({ name: node.name })}
									checked={selection.has(node.id)}
									onclick={(e) => selection.toggle(node.id, order, e.shiftKey)}
								/>
							</td>
							<td>
								<div class="name-cell">
									<span class="thumb"><Thumb {node} /></span>
									{#if node.kind === 'folder'}
										<a class="name" href={resolve('/(app)/folders/[id]', { id: node.id })}
											>{node.name}</a
										>
									{:else}
										<button class="name as-link" onclick={() => open(node)}>{node.name}</button>
									{/if}
								</div>
							</td>
							<td class="num muted"
								>{node.kind === 'folder' ? '—' : formatSize(node.size, locale)}</td
							>
							<td class="date muted">{formatDate(node.updated, locale)}</td>
							<td class="act">
								<ActionsMenu
									label={m.actions_for({ name: node.name })}
									actions={actionsFor(node)}
								/>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		{/if}
	{/if}

	{#if dragDepth > 0}
		<div class="dropzone" aria-hidden="true">
			<UploadIcon size={28} />
			<p>{m.drop_here({ folder: folderName })}</p>
		</div>
	{/if}
</div>

<NewFolderDialog bind:open={newFolderOpen} parent={folderId} />
<RenameDialog bind:node={renaming} />
<ShareDialog bind:target={sharing} />
<MoveDialog
	bind:open={moveOpen}
	items={moveItems}
	start={folderId}
	onmove={(destination, name) => {
		selection.clear();
		move(moveItems, destination, name);
	}}
/>
<p class="visually-hidden" aria-live="polite">{announcement}</p>
<Viewer items={files} bind:index={viewerIndex} ondownload={download} />

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
	a.name:hover,
	.as-link:hover {
		text-decoration: underline;
	}
	.as-link {
		border: 0;
		padding: 0;
		background: none;
		font: inherit;
		font-size: var(--text-md);
		text-align: left;
		cursor: pointer;
	}
	.act {
		width: 3.5rem;
		padding: 0 var(--space-2);
		text-align: right;
	}
	.list {
		overflow: visible;
	}
	.thumb {
		display: grid;
		place-items: center;
		flex: none;
		width: 2.25rem;
		height: 2.25rem;
		border-radius: var(--radius-md);
		overflow: hidden;
	}
	.segmented {
		display: inline-flex;
		padding: 2px;
		gap: 2px;
		background: var(--color-surface-sunken);
		border-radius: var(--radius-md);
	}
	.segmented button {
		display: grid;
		place-items: center;
		width: 2.75rem;
		height: 2.5rem;
		border: 0;
		border-radius: var(--radius-sm);
		background: transparent;
		color: var(--color-text-muted);
		cursor: pointer;
	}
	.segmented button[aria-checked='true'] {
		background: var(--color-surface);
		color: var(--color-text);
		box-shadow: var(--shadow-sm);
	}
	.grid {
		list-style: none;
		margin: 0;
		padding: 0;
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(10.5rem, 1fr));
		gap: var(--space-4);
	}
	.tile {
		position: relative;
		display: grid;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
		overflow: hidden;
		transition:
			box-shadow var(--duration-fast) var(--ease-standard),
			border-color var(--duration-fast) var(--ease-standard);
	}
	.tile:hover {
		box-shadow: var(--shadow-md);
	}
	.tile.selected {
		border-color: var(--color-accent);
		box-shadow: 0 0 0 1px var(--color-accent);
	}
	.tile.drop {
		outline: 2px dashed var(--color-accent);
		outline-offset: -2px;
		background: var(--color-accent-subtle);
	}
	.preview {
		position: relative;
		display: grid;
		place-items: center;
		aspect-ratio: 4 / 3;
		overflow: hidden;
		background: var(--color-surface-sunken);
	}
	.preview :global(img) {
		position: absolute;
		inset: 0;
	}
	.preview.folder {
		background: var(--color-accent-subtle);
	}
	.meta {
		display: grid;
		gap: 2px;
		padding: var(--space-2) var(--space-3) var(--space-3);
		min-width: 0;
	}
	.tile-name {
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		color: var(--color-text);
		text-decoration: none;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.small {
		font-size: var(--text-xs);
	}
	.tile-check {
		position: absolute;
		top: var(--space-2);
		left: var(--space-2);
		width: 1.25rem;
		height: 1.25rem;
		accent-color: var(--color-accent);
		cursor: pointer;
		opacity: 0;
	}
	.tile-menu {
		position: absolute;
		top: var(--space-1);
		right: var(--space-1);
		border-radius: var(--radius-md);
		background: color-mix(in srgb, var(--color-surface) 85%, transparent);
		opacity: 0;
	}
	.tile:hover .tile-check,
	.tile:hover .tile-menu,
	.tile:focus-within .tile-check,
	.tile:focus-within .tile-menu,
	.tile.selected .tile-check,
	.grid:has(.tile.selected) .tile-check {
		opacity: 1;
	}
	@media (hover: none) {
		.tile-check,
		.tile-menu {
			opacity: 1;
		}
	}
	.check {
		width: 2.75rem;
		padding: 0 0 0 var(--space-4);
	}
	.check input {
		width: 1.125rem;
		height: 1.125rem;
		accent-color: var(--color-accent);
		cursor: pointer;
		vertical-align: middle;
	}
	tbody tr.selected {
		background: var(--color-accent-subtle);
	}
	tbody tr.drop,
	.crumbs a.drop {
		background: var(--color-accent-subtle);
		outline: 2px dashed var(--color-accent);
		outline-offset: -2px;
	}
	.selbar {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-1) var(--space-1) var(--space-1) var(--space-4);
		border-radius: var(--radius-md);
		background: var(--color-accent-subtle);
	}
	.count {
		font-weight: var(--weight-medium);
		color: var(--color-accent);
		margin-right: var(--space-2);
	}
	.icon-btn {
		display: grid;
		place-items: center;
		width: 2.75rem;
		height: 2.75rem;
		border: 0;
		border-radius: var(--radius-md);
		background: transparent;
		color: var(--color-text);
		cursor: pointer;
	}
	.icon-btn:hover {
		background: var(--color-surface-sunken);
	}
	.action-error {
		margin-bottom: var(--space-4);
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
