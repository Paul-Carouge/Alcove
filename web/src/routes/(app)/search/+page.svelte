<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { Search as SearchIcon } from '@lucide/svelte';
	import FileIcon from '#lib/drive/FileIcon.svelte';
	import { formatDate, formatSize } from '#lib/drive/format.js';
	import type { DriveNode } from '#lib/drive/types.js';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import { pb } from '#lib/pb.js';
	import Alert from '#lib/ui/Alert.svelte';

	const locale = getLocale();
	const LIMIT = 200;
	const q = $derived(page.url.searchParams.get('q')?.trim() ?? '');
	let results = $state<DriveNode[] | null>(null);
	let total = $state(0);
	let failed = $state(false);
	let input = $state('');

	$effect(() => {
		const query = q;
		input = query;
		if (!query) {
			results = [];
			return;
		}
		results = null;
		pb.collection('nodes')
			.getList<DriveNode>(1, LIMIT, {
				filter: pb.filter('name ~ {:q} && trashed_at = ""', { q: query }),
				sort: '-kind,name',
				expand: 'parent'
			})
			.then((res) => {
				if (query !== q) return;
				results = res.items;
				total = res.totalItems;
				failed = false;
			})
			.catch(() => (failed = true));
	});

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
{:else if q && results.length === 0}
	<p class="muted">{m.search_none({ q })}</p>
{:else if q}
	<p class="muted" role="status">
		{total > LIMIT ? m.search_many({ count: LIMIT, total }) : m.search_count({ count: total })}
	</p>
	<ul class="results">
		{#each results as n (n.id)}
			<li>
				<FileIcon kind={n.kind} mime={n.mime} />
				<div class="text">
					{#if n.kind === 'folder'}
						<a class="name" href={resolve('/(app)/folders/[id]', { id: n.id })}>{n.name}</a>
					{:else}
						<a class="name" href={folderOf(n)}>{n.name}</a>
					{/if}
					<span class="muted small">
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
		font-size: var(--text-2xl);
		letter-spacing: -0.02em;
		margin: var(--space-2) 0 var(--space-4);
	}
	.search {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		max-width: 36rem;
		min-height: 3rem;
		margin-bottom: var(--space-4);
		padding: 0 var(--space-4);
		border: 1px solid var(--color-border-strong);
		border-radius: var(--radius-md);
		background: var(--color-surface);
		color: var(--color-text-muted);
	}
	.search:focus-within {
		outline: 2px solid var(--color-focus);
		outline-offset: 1px;
	}
	.search input {
		flex: 1;
		border: 0;
		background: transparent;
		color: var(--color-text);
		font: inherit;
		outline: none;
	}
	.results {
		max-width: 48rem;
		margin: 0;
		padding: 0;
		list-style: none;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
	}
	.results li {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		min-height: 3.5rem;
		padding: var(--space-2) var(--space-4);
	}
	.results li + li {
		border-top: 1px solid var(--color-border);
	}
	.text {
		display: grid;
		min-width: 0;
	}
	.name {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		color: var(--color-text);
		font-weight: var(--weight-medium);
		text-decoration: none;
	}
	.name:hover {
		text-decoration: underline;
	}
	.muted {
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.small {
		font-size: var(--text-xs);
	}
</style>
