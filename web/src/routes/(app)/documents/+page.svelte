<script lang="ts">
	import { Check, Copy, FileSearch, FileText, ScanText, Tag as TagIcon } from '@lucide/svelte';
	import {
		documentText,
		listDocuments,
		makeSearchable,
		searchableStatus,
		type DocumentFilter,
		type DocumentRecord
	} from '#lib/documents/api.js';
	import { downloadNode } from '#lib/drive/api.js';
	import { formatDate } from '#lib/drive/format.js';
	import { onDocumentChange } from '#lib/drive/live.js';
	import Thumb from '#lib/drive/Thumb.svelte';
	import type { DriveNode } from '#lib/drive/types.js';
	import Viewer from '#lib/drive/Viewer.svelte';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import EmptyState from '#lib/ui/EmptyState.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';
	import TagChip from '#lib/tags/TagChip.svelte';
	import TagsDialog from '#lib/tags/TagsDialog.svelte';
	import { tags } from '#lib/tags/tags.svelte.js';

	const locale = getLocale();
	const PER_PAGE = 50;

	let filter = $state<DocumentFilter>('all');
	let tagFilter = $state('');
	// Searchable copies being made, by source node id.
	let making = $state<Record<string, 'running' | 'done' | 'failed'>>({});
	let tagging = $state<DriveNode | null>(null);
	let taggingOpen = $state(false);
	let docs = $state<DocumentRecord[] | null>(null);
	let total = $state(0);
	let page = $state(1);
	let failed = $state(false);
	let loadingMore = $state(false);
	let viewerIndex = $state(-1);

	let textOpen = $state(false);
	let textDoc = $state<DocumentRecord | null>(null);
	let fullText = $state<string | null>(null);
	let copied = $state(false);

	const filters: { value: DocumentFilter; label: () => string }[] = [
		{ value: 'all', label: m.documents_all },
		{ value: 'pdf', label: m.documents_pdf },
		{ value: 'image', label: m.documents_scans },
		{ value: 'text', label: m.documents_text }
	];

	const nodes = $derived((docs ?? []).map((d) => d.expand?.node).filter((n) => !!n) as DriveNode[]);

	async function load(kind: DocumentFilter, p = 1, tag = tagFilter) {
		try {
			const res = await listDocuments(kind, p, PER_PAGE, tag);
			if (kind !== filter || tag !== tagFilter) return;
			docs = p === 1 ? res.items : [...(docs ?? []), ...res.items];
			total = res.totalItems;
			page = p;
			failed = false;
		} catch {
			failed = true;
		}
	}

	$effect(() => {
		const kind = filter;
		const tag = tagFilter;
		docs = null;
		load(kind, 1, tag);
	});
	$effect(() => {
		tags.load().catch(() => {});
	});
	// A deleted tag can no longer filter.
	$effect(() => {
		if (tagFilter && tags.loaded && !tags.byId.has(tagFilter)) tagFilter = '';
	});
	const tagsOf = (node: DriveNode) =>
		(node.tags ?? []).map((id) => tags.byId.get(id)).filter((t) => t !== undefined);

	// Documents are read in the background: refresh when one changes (debounced).
	$effect(() => {
		let timer: ReturnType<typeof setTimeout> | undefined;
		const stop = onDocumentChange(() => {
			clearTimeout(timer);
			timer = setTimeout(() => load(filter, 1), 600);
		});
		return () => {
			clearTimeout(timer);
			stop();
		};
	});

	async function more() {
		loadingMore = true;
		await load(filter, page + 1);
		loadingMore = false;
	}

	async function searchable(node: DriveNode) {
		making[node.id] = 'running';
		try {
			let job = await makeSearchable(node.id);
			while (job.status === 'running') {
				await new Promise((r) => setTimeout(r, 2000));
				job = await searchableStatus(node.id);
			}
			making[node.id] = job.status === 'done' ? 'done' : 'failed';
		} catch {
			making[node.id] = 'failed';
		}
	}

	async function showText(doc: DocumentRecord) {
		textDoc = doc;
		fullText = null;
		copied = false;
		textOpen = true;
		try {
			fullText = await documentText(doc.id);
		} catch {
			fullText = '';
		}
	}

	async function copyText() {
		if (!fullText) return;
		await navigator.clipboard.writeText(fullText);
		copied = true;
	}

	function open(doc: DocumentRecord) {
		viewerIndex = nodes.findIndex((n) => n.id === doc.node);
	}

	function statusText(doc: DocumentRecord): string {
		switch (doc.status) {
			case 'pending':
				return m.documents_reading();
			case 'failed':
				return m.documents_failed();
			case 'skipped':
				return doc.reason === 'ocr-off'
					? m.documents_ocr_off()
					: doc.reason === 'no-tools'
						? m.documents_no_tools()
						: m.documents_not_read();
		}
		const parts: string[] = [];
		if (doc.pages > 1) parts.push(m.documents_pages({ count: doc.pages }));
		if (doc.method === 'ocr') parts.push(m.documents_read_ocr());
		return parts.join(' · ');
	}
</script>

<svelte:head>
	<title>{m.nav_documents()}</title>
</svelte:head>

<div class="head">
	<h1>{m.nav_documents()}</h1>
</div>

<div class="chips" role="radiogroup" aria-label={m.documents_filter()}>
	{#each filters as f (f.value)}
		<button
			role="radio"
			aria-checked={filter === f.value}
			class:on={filter === f.value}
			onclick={() => (filter = f.value)}>{f.label()}</button
		>
	{/each}
</div>

{#if tags.items.length}
	<div class="tag-filter" role="radiogroup" aria-label={m.tags_filter()}>
		<button
			role="radio"
			aria-checked={tagFilter === ''}
			class="tag-all"
			class:on={tagFilter === ''}
			onclick={() => (tagFilter = '')}>{m.tags_any()}</button
		>
		{#each tags.items as t (t.id)}
			<button
				role="radio"
				aria-checked={tagFilter === t.id}
				class="tag-opt"
				class:on={tagFilter === t.id}
				onclick={() => (tagFilter = tagFilter === t.id ? '' : t.id)}
				><TagChip tag={t} size="md" /></button
			>
		{/each}
	</div>
{/if}

{#if failed}
	<Alert>{m.error_load()}</Alert>
{:else if docs === null}
	<ul class="list" aria-busy="true" aria-label={m.loading()}>
		{#each [0, 1, 2, 3] as i (i)}
			<li class="row skeleton"><span class="thumb"></span><span class="lines"></span></li>
		{/each}
	</ul>
{:else if docs.length === 0}
	<div class="empty">
		<EmptyState icon={FileText} title={m.documents_empty_title()}>
			{m.documents_empty()}
		</EmptyState>
	</div>
{:else}
	<p class="muted" role="status">{m.documents_count({ count: total })}</p>
	<ul class="list">
		{#each docs as doc (doc.id)}
			{@const node = doc.expand?.node}
			{#if node}
				<li class="row">
					<button
						class="thumb"
						onclick={() => open(doc)}
						aria-label={m.documents_open({ name: node.name })}
					>
						<Thumb {node} size="96x96" iconSize={22} />
					</button>
					<div class="main">
						<button class="name" onclick={() => open(doc)}>{node.name}</button>
						{#if doc.status === 'ready' && doc.text}
							<p class="excerpt">{doc.text}</p>
						{/if}
						{#if tagsOf(node).length}
							<p class="row-tags">
								{#each tagsOf(node) as t (t.id)}<TagChip tag={t} />{/each}
							</p>
						{/if}
						<p class="meta">
							{#if doc.status === 'pending'}<span class="dot" aria-hidden="true"></span>{/if}
							{[statusText(doc), formatDate(node.updated, locale)].filter(Boolean).join(' · ')}
							{#if making[node.id] === 'running'}
								<span class="job" role="status">· {m.searchable_running()}</span>
							{:else if making[node.id] === 'done'}
								<span class="job done" role="status">· {m.searchable_done()}</span>
							{:else if making[node.id] === 'failed'}
								<span class="job failed" role="status">· {m.searchable_failed()}</span>
							{/if}
						</p>
					</div>
					<div class="row-actions">
						{#if doc.method === 'ocr'}
							<button
								class="icon-btn"
								aria-label={m.searchable_make({ name: node.name })}
								title={m.searchable_hint()}
								disabled={making[node.id] === 'running'}
								onclick={() => searchable(node)}
							>
								<FileSearch size={18} aria-hidden="true" />
							</button>
						{/if}
						<button
							class="icon-btn"
							aria-label={m.tags_edit_for({ name: node.name })}
							onclick={() => {
								tagging = node;
								taggingOpen = true;
							}}
						>
							<TagIcon size={18} aria-hidden="true" />
						</button>
						{#if doc.status === 'ready' && doc.text}
							<Button variant="secondary" onclick={() => showText(doc)}>
								<ScanText size={16} aria-hidden="true" />
								<span class="text-label">{m.documents_show_text()}</span>
							</Button>
						{/if}
					</div>
				</li>
			{/if}
		{/each}
	</ul>
	{#if docs.length < total}
		<div class="more">
			<Button variant="secondary" loading={loadingMore} onclick={more}>{m.load_more()}</Button>
		</div>
	{/if}
{/if}

<Viewer items={nodes} bind:index={viewerIndex} ondownload={downloadNode} />
<TagsDialog
	bind:open={taggingOpen}
	node={tagging}
	onsaved={(ids) => {
		// The document list does not follow node changes live: update the row in place.
		docs = (docs ?? []).map((d) =>
			d.expand?.node && d.expand.node.id === tagging?.id
				? { ...d, expand: { ...d.expand, node: { ...d.expand.node, tags: ids } } }
				: d
		);
		if (tagFilter && !ids.includes(tagFilter)) load(filter, 1);
	}}
/>

<Dialog bind:open={textOpen} title={textDoc?.expand?.node?.name ?? m.documents_text_title()} wide>
	{#if fullText === null}
		<p class="muted">{m.loading()}</p>
	{:else}
		<pre class="fulltext">{fullText}</pre>
		<div class="actions">
			<Button variant="secondary" onclick={copyText}>
				{#if copied}<Check size={16} aria-hidden="true" />{m.copied()}{:else}<Copy
						size={16}
						aria-hidden="true"
					/>{m.documents_copy()}{/if}
			</Button>
			<Button onclick={() => (textOpen = false)}>{m.close()}</Button>
		</div>
	{/if}
</Dialog>

<style>
	.head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		flex-wrap: wrap;
		gap: var(--space-4);
		min-height: 3.5rem;
		align-items: flex-end;
		margin: 0 0 var(--space-4);
	}
	.chips {
		display: inline-flex;
		max-width: 100%;
		overflow-x: auto;
		scrollbar-width: none;
		gap: var(--space-1);
		margin-bottom: var(--space-4);
		padding: var(--space-1);
		border-radius: var(--radius-full);
		background: var(--color-surface-sunken);
	}
	.chips button {
		flex-shrink: 0;
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
		transition:
			background var(--duration-fast) var(--ease-standard),
			color var(--duration-fast) var(--ease-standard);
	}
	.chips button:hover {
		color: var(--color-text);
	}
	.chips button.on {
		background: var(--color-surface);
		color: var(--color-text);
		box-shadow: var(--shadow-sm);
	}
	.tag-filter {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-2);
		margin: calc(-1 * var(--space-1)) 0 var(--space-4);
	}
	.tag-filter button {
		display: inline-flex;
		align-items: center;
		min-height: 2.75rem;
		padding: 0 var(--space-1);
		border: 1px solid transparent;
		border-radius: var(--radius-full);
		background: none;
		cursor: pointer;
		transition:
			border-color var(--duration-fast) var(--ease-standard),
			background var(--duration-fast) var(--ease-standard);
	}
	.tag-filter button:hover {
		border-color: var(--color-border);
	}
	.tag-filter .tag-all {
		padding: 0 var(--space-3);
		color: var(--color-text-muted);
		font: inherit;
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
	}
	.tag-filter button.on {
		border-color: var(--color-accent);
		background: var(--color-surface);
		box-shadow: var(--shadow-sm);
	}
	.tag-filter .tag-all.on {
		color: var(--color-text);
	}
	.row-tags {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-1);
		margin: var(--space-1) 0 0;
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
	.icon-btn:disabled {
		opacity: 0.5;
		cursor: progress;
	}
	.job {
		color: var(--color-accent);
		font-weight: var(--weight-medium);
	}
	.job.done {
		color: var(--color-success);
	}
	.job.failed {
		color: var(--color-danger);
	}
	.icon-btn:hover {
		background: var(--color-surface-sunken);
		color: var(--color-text);
	}
	.muted {
		margin: 0 0 var(--space-2);
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.list {
		max-width: 56rem;
		margin: 0;
		padding: 0;
		list-style: none;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
		box-shadow: var(--shadow-sm);
		overflow: hidden;
	}
	.row {
		display: flex;
		align-items: center;
		gap: var(--space-4);
		padding: var(--space-4) var(--space-4) var(--space-4) var(--space-5);
		transition: background var(--duration-fast) var(--ease-standard);
	}
	.row:not(.skeleton):hover {
		background: color-mix(in srgb, var(--color-surface-sunken) 60%, transparent);
	}
	.row-actions {
		display: flex;
		flex: none;
		align-items: center;
		gap: var(--space-1);
	}
	.row + .row {
		border-top: 1px solid var(--color-border);
	}
	.thumb {
		display: grid;
		place-items: center;
		flex: none;
		width: 3.5rem;
		height: 4.25rem;
		padding: 0;
		overflow: hidden;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-sm);
		box-shadow: var(--shadow-sm);
		background: var(--color-surface-sunken);
		color: var(--color-text-muted);
		cursor: pointer;
	}
	.main {
		display: grid;
		gap: var(--space-1);
		flex: 1;
		min-width: 0;
	}
	.name {
		justify-self: start;
		max-width: 100%;
		padding: 0;
		overflow: hidden;
		border: 0;
		background: none;
		color: var(--color-text);
		font: inherit;
		font-family: var(--font-display);
		font-size: var(--text-lg);
		font-weight: var(--weight-medium);
		line-height: var(--leading-tight);
		text-align: left;
		text-overflow: ellipsis;
		white-space: nowrap;
		cursor: pointer;
	}
	.name:hover {
		text-decoration: underline;
		text-decoration-color: var(--color-border-strong);
	}
	.excerpt {
		display: -webkit-box;
		-webkit-line-clamp: 2;
		line-clamp: 2;
		-webkit-box-orient: vertical;
		margin: 0;
		overflow: hidden;
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.meta {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		margin: 0;
		color: var(--color-text-muted);
		font-size: var(--text-xs);
	}
	.dot {
		width: 0.5rem;
		height: 0.5rem;
		border-radius: var(--radius-full);
		background: var(--color-accent);
		animation: pulse 1.2s ease-in-out infinite;
	}
	@keyframes pulse {
		50% {
			opacity: 0.3;
		}
	}
	.skeleton .thumb,
	.skeleton .lines {
		border: 0;
		background: var(--color-surface-sunken);
		animation: pulse 1.4s ease-in-out infinite;
	}
	.skeleton .lines {
		flex: 1;
		height: 2.5rem;
		border-radius: var(--radius-sm);
	}
	.more {
		display: flex;
		justify-content: center;
		max-width: 56rem;
		margin-top: var(--space-4);
	}
	.empty {
		max-width: 56rem;
	}
	.fulltext {
		max-height: min(60vh, 32rem);
		margin: 0;
		padding: var(--space-5);
		overflow: auto;
		border-radius: var(--radius-lg);
		background: var(--color-surface-sunken);
		font: inherit;
		font-size: var(--text-sm);
		line-height: var(--leading-normal);
		white-space: pre-wrap;
		overflow-wrap: anywhere;
	}
	.actions {
		display: flex;
		justify-content: flex-end;
		gap: var(--space-2);
	}
	@media (max-width: 600px) {
		/* Phones: the buttons go on their own line so names stay readable. */
		.row {
			flex-wrap: wrap;
		}
		.main {
			flex-basis: calc(100% - 3.5rem - var(--space-4));
		}
		.row-actions {
			width: 100%;
			justify-content: flex-end;
		}
		.head {
			flex-direction: column;
			align-items: stretch;
			/* A wrapping column would stretch to its widest child, the scrolling tools row. */
			flex-wrap: nowrap;
		}
		/* Icon only on phones; the label stays for screen readers. */
		.row .text-label {
			position: absolute;
			width: 1px;
			height: 1px;
			overflow: hidden;
			clip-path: inset(50%);
			white-space: nowrap;
		}
	}
	@media (prefers-reduced-motion: reduce) {
		.dot,
		.skeleton .thumb,
		.skeleton .lines {
			animation: none;
		}
	}
</style>
