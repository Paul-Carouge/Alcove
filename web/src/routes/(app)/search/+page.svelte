<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { NotebookPen, Search as SearchIcon } from '@lucide/svelte';
	import FileIcon from '#lib/drive/FileIcon.svelte';
	import { formatDate, formatSize } from '#lib/drive/format.js';
	import type { DriveNode } from '#lib/drive/types.js';
	import { search, type SearchHit } from '#lib/documents/api.js';
	import { excerpt, searchNotes, type Note } from '#lib/notes/notes.svelte.js';
	import Snippet from '#lib/documents/Snippet.svelte';
	import TagChip from '#lib/tags/TagChip.svelte';
	import { tags } from '#lib/tags/tags.svelte.js';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import Alert from '#lib/ui/Alert.svelte';
	import EmptyState from '#lib/ui/EmptyState.svelte';

	const locale = getLocale();
	const q = $derived(page.url.searchParams.get('q')?.trim() ?? '');
	let results = $state<SearchHit[] | null>(null);
	let failed = $state(false);
	let input = $state('');

	// Names first, then documents whose text matches (ADR 0025).
	$effect(() => {
		const query = q.slice(0, 200);
		input = q;
		if (!query) {
			results = [];
			return;
		}
		results = null;
		const ctrl = new AbortController();
		search(query, ctrl.signal)
			.then((hits) => {
				results = hits;
				failed = false;
			})
			.catch((err) => {
				if (!ctrl.signal.aborted) failed = !!err;
			});
		return () => ctrl.abort();
	});
	// Notes whose title or text contains what was typed (ADR 0027).
	let notes = $state<Note[]>([]);
	$effect(() => {
		const query = q.slice(0, 200);
		notes = [];
		if (!query) return;
		let live = true;
		searchNotes(query)
			.then((found) => live && (notes = found))
			.catch(() => {});
		return () => {
			live = false;
		};
	});
	$effect(() => {
		tags.load().catch(() => {});
	});
	const tagsOf = (n: DriveNode) =>
		(n.tags ?? []).map((id) => tags.byId.get(id)).filter((t) => t !== undefined);
	const inText = $derived(results?.filter((h) => h.match === 'content').length ?? 0);

	function submit(event: SubmitEvent) {
		event.preventDefault();
		const value = input.trim();
		if (!value) return;
		const url = `${resolve('/(app)/search')}?q=${encodeURIComponent(value)}`;
		// eslint-disable-next-line svelte/no-navigation-without-resolve -- resolved path plus a query
		goto(url, { replace: true });
	}

	const folderOf = (n: DriveNode) =>
		n.parent ? resolve('/(app)/folders/[id]', { id: n.parent }) : resolve('/(app)');
	const parentName = (n: DriveNode) =>
		(n.expand as { parent?: { name?: string } } | undefined)?.parent?.name ?? m.nav_files();
</script>

<svelte:head>
	<title>{q ? m.search_title_query({ q }) : m.search_title()}</title>
</svelte:head>

<h1>{m.search_title()}</h1>
<form class="search" role="search" onsubmit={submit}>
	<SearchIcon size={18} aria-hidden="true" />
	<input
		type="search"
		bind:value={input}
		placeholder={m.search_placeholder()}
		aria-label={m.search_placeholder()}
		autocomplete="off"
	/>
</form>

{#if failed}
	<Alert>{m.error_load()}</Alert>
{:else if results === null}
	<p class="muted">{m.loading()}</p>
{:else if q && results.length === 0 && notes.length === 0}
	<div class="results-empty">
		<EmptyState icon={SearchIcon} title={m.search_none({ q })} compact />
	</div>
{:else if q}
	<p class="muted" role="status">
		{[
			results.length ? m.search_count({ count: results.length }) : '',
			inText ? m.search_in_text_count({ count: inText }) : '',
			notes.length ? m.notes_count({ count: notes.length }) : ''
		]
			.filter(Boolean)
			.join(' · ')}
	</p>
	{#if notes.length}
		<h2 class="section">{m.nav_notes()}</h2>
		<ul class="results notes">
			{#each notes as n (n.id)}
				<li>
					<NotebookPen size={20} strokeWidth={1.75} aria-hidden="true" />
					<div class="text">
						<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- resolved path plus a query -->
						<a class="name" href={`${resolve('/(app)/notes')}?n=${encodeURIComponent(n.id)}`}
							>{n.title.trim() || excerpt(n.body, 60) || m.notes_untitled()}</a
						>
						{#if n.title.trim() && excerpt(n.body)}
							<span class="muted small">{excerpt(n.body)}</span>
						{/if}
					</div>
				</li>
			{/each}
		</ul>
		{#if results.length}<h2 class="section">{m.nav_files()}</h2>{/if}
	{/if}
	<ul class="results">
		{#each results as { node: n, match, snippet } (n.id)}
			<li>
				<FileIcon kind={n.kind} mime={n.mime} />
				<div class="text">
					{#if n.kind === 'folder'}
						<a class="name" href={resolve('/(app)/folders/[id]', { id: n.id })}>{n.name}</a>
					{:else}
						<a class="name" href={folderOf(n)}>{n.name}</a>
					{/if}
					{#if match === 'content' && snippet?.length}
						<Snippet segments={snippet} />
					{/if}
					{#if tagsOf(n).length}
						<span class="tags"
							>{#each tagsOf(n) as t (t.id)}<TagChip tag={t} />{/each}</span
						>
					{/if}
					<span class="muted small">
						{#if match === 'content'}<span class="badge">{m.search_found_in_text()}</span>{/if}
						{#if match === 'tag'}<span class="badge">{m.search_found_by_tag()}</span>{/if}
						{m.search_in({ folder: parentName(n) })}
						{#if n.kind === 'file'}· {formatSize(n.size, locale)} · {formatDate(
								n.updated,
								locale
							)}{/if}
					</span>
				</div>
			</li>
		{/each}
	</ul>
{/if}

<style>
	h1 {
		margin: 0 0 var(--space-5);
		padding-top: var(--space-3);
	}
	.search {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		max-width: 40rem;
		min-height: 3.25rem;
		margin-bottom: var(--space-5);
		padding: 0 var(--space-5);
		border: 1px solid var(--color-border-strong);
		border-radius: var(--radius-full);
		background: var(--color-surface);
		box-shadow: var(--shadow-sm);
		color: var(--color-text-muted);
		transition:
			border-color var(--duration-fast) var(--ease-standard),
			box-shadow var(--duration-fast) var(--ease-standard);
	}
	.search:focus-within {
		border-color: var(--color-focus);
		box-shadow:
			0 0 0 1px var(--color-focus),
			0 0 0 5px var(--color-accent-subtle);
	}
	.search input {
		flex: 1;
		min-height: 3rem;
		border: 0;
		background: transparent;
		color: var(--color-text);
		font: inherit;
		font-size: var(--text-lg);
		outline: none;
	}
	.search input::placeholder {
		color: var(--color-text-muted);
	}
	.results,
	.results-empty {
		max-width: 52rem;
	}
	.results:empty {
		display: none;
	}
	.notes {
		margin-bottom: var(--space-5);
	}
	.notes li > :global(svg) {
		flex: none;
		margin-top: var(--space-2);
		color: var(--color-accent);
	}
	.section {
		margin: 0 0 var(--space-3);
		font-size: var(--text-lg);
	}
	.results {
		margin: 0;
		padding: 0;
		list-style: none;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
		box-shadow: var(--shadow-sm);
	}
	.results li {
		display: flex;
		align-items: flex-start;
		gap: var(--space-4);
		min-height: 3.5rem;
		padding: var(--space-3) var(--space-5);
	}
	.results li > :global(.icon) {
		margin-top: var(--space-1);
	}
	.results li + li {
		border-top: 1px solid var(--color-border);
	}
	.text {
		display: grid;
		gap: var(--space-1);
		min-width: 0;
		padding: var(--space-1) 0;
	}
	.name {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		color: var(--color-text);
		font-family: var(--font-display);
		font-size: var(--text-lg);
		font-weight: var(--weight-medium);
		line-height: var(--leading-tight);
		text-decoration: none;
	}
	.name:hover {
		text-decoration: underline;
		text-decoration-color: var(--color-border-strong);
	}
	.muted {
		margin: 0 0 var(--space-3);
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.small {
		margin: 0;
		font-size: var(--text-xs);
	}
	.tags {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-1);
	}
	.badge {
		display: inline-block;
		margin-right: var(--space-1);
		padding: 0 var(--space-2);
		border-radius: var(--radius-full);
		background: var(--color-accent-subtle);
		color: var(--color-accent);
		font-weight: var(--weight-medium);
	}
	@media (max-width: 600px) {
		.search {
			padding: 0 var(--space-4);
		}
		.search input {
			font-size: var(--text-md);
		}
		.results li {
			padding: var(--space-3) var(--space-4);
		}
	}
</style>
