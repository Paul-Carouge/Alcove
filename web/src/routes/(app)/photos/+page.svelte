<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page as routePage } from '$app/state';
	import { untrack } from 'svelte';
	import { SvelteSet } from 'svelte/reactivity';
	import { BookImage, CircleCheck, Image as ImageIcon, X } from '@lucide/svelte';
	import { onMediaChange } from '#lib/drive/live.js';
	import { m } from '#lib/paraglide/messages.js';
	import {
		fileToken,
		getMedia,
		listMedia,
		setFavorite,
		type Media,
		type PhotoFilter
	} from '#lib/photos/api.js';
	import { addToAlbum, getAlbum } from '#lib/photos/albums.js';
	import AlbumPicker from '#lib/photos/AlbumPicker.svelte';
	import PhotoGrid from '#lib/photos/PhotoGrid.svelte';
	import PhotoViewer from '#lib/photos/PhotoViewer.svelte';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';

	let filter = $state<PhotoFilter>('all');
	let items = $state<Media[]>([]);
	let total = $state(0);
	let page = $state(0);
	let loading = $state(false);
	let failed = $state(false);
	let token = $state('');
	let viewerIndex = $state(-1);
	let sentinel = $state<HTMLDivElement>();

	// Selection mode: add several photos to an album at once.
	let selected = $state<SvelteSet<string> | null>(null);
	let pickerOpen = $state(false);
	let pickerIds = $state<string[]>([]);
	let status = $state('');
	let adding = $state(false);
	/** Opened from an album's "Add photos": the selection goes straight there. */
	let target = $state<{ id: string; name: string } | null>(null);

	const hasMore = $derived(items.length < total);

	// Same order as the server (-taken_at,-id): a video's date is only known once probed.
	const sortTimeline = (list: Media[]) =>
		list.toSorted((a, b) => b.taken_at.localeCompare(a.taken_at) || b.id.localeCompare(a.id));
	const matches = (it: Media) =>
		filter === 'all' ||
		(filter === 'videos' && it.kind === 'video') ||
		(filter === 'favorites' && it.favorite);

	async function loadMore() {
		if (loading) return;
		loading = true;
		try {
			const res = await listMedia(page + 1, filter);
			items = page === 0 ? res.items : [...items, ...res.items];
			total = res.totalItems;
			page = res.page;
			failed = false;
		} catch {
			failed = true;
		} finally {
			loading = false;
		}
	}

	function setFilter(f: PhotoFilter) {
		if (f === filter) return;
		filter = f;
		items = [];
		total = 0;
		page = 0;
		loadMore();
	}

	$effect(() => {
		fileToken().then((t) => (token = t));
		untrack(loadMore);
		const addTo = routePage.url.searchParams.get('addTo');
		if (addTo) {
			getAlbum(addTo)
				.then((a) => {
					target = { id: a.id, name: a.name };
					selected = new SvelteSet();
				})
				.catch(() => {});
		}
		// Tokens expire: refresh them so lazily loaded thumbnails keep working.
		const refresh = setInterval(() => fileToken().then((t) => (token = t)), 60_000);
		const stop = onMediaChange<Media>(async ({ action, record }) => {
			const full = action === 'delete' ? null : await getMedia(record.id).catch(() => null);
			const i = items.findIndex((x) => x.id === record.id);
			if (!full || full.expand?.node?.trashed_at) {
				if (i >= 0) {
					items = items.filter((x) => x.id !== record.id);
					total -= 1;
				}
				return;
			}
			if (i >= 0) items = sortTimeline(items.with(i, full));
			else if (matches(full)) {
				items = sortTimeline([...items, full]);
				total += 1;
			}
		});
		return () => {
			clearInterval(refresh);
			stop();
		};
	});

	// Infinite scroll.
	$effect(() => {
		if (!sentinel) return;
		const io = new IntersectionObserver(
			(entries) => {
				if (entries[0]?.isIntersecting && hasMore && !loading) loadMore();
			},
			{ rootMargin: '800px' }
		);
		io.observe(sentinel);
		return () => io.disconnect();
	});

	async function toggleFavorite(item: Media) {
		const next = !item.favorite;
		item.favorite = next; // optimistic; the live update confirms
		try {
			await setFavorite(item.id, next);
			if (filter === 'favorites' && !next) items = items.filter((x) => x.id !== item.id);
		} catch {
			item.favorite = !next;
		}
	}

	function toggleSelect(item: Media) {
		if (!selected) return;
		if (selected.has(item.id)) selected.delete(item.id);
		else selected.add(item.id);
	}

	function endSelection() {
		selected = null;
		if (target) goto(resolve('/(app)/albums/[id]', { id: target.id }));
	}

	function chooseAlbum(ids: string[]) {
		pickerIds = ids;
		pickerOpen = true;
	}

	async function addSelection() {
		if (!selected?.size) return;
		if (!target) return chooseAlbum([...selected]);
		adding = true;
		try {
			await addToAlbum(target.id, [...selected]);
			goto(resolve('/(app)/albums/[id]', { id: target.id }));
		} catch {
			status = m.error_unexpected();
		} finally {
			adding = false;
		}
	}

	function added(album: { id: string; name: string }, count: number) {
		status = m.album_added({ count, name: album.name });
		selected = null;
	}
</script>

<svelte:head>
	<title>{m.photos_title()}</title>
</svelte:head>

<div class="head">
	<h1>{target ? m.album_add_photos_to({ name: target.name }) : m.photos_title()}</h1>
	<div class="tools">
		<div class="chips" role="radiogroup" aria-label={m.photos_filter_label()}>
			{#each [['all', m.photos_all], ['favorites', m.photos_favorites], ['videos', m.photos_videos]] as [value, label] (value)}
				<button
					role="radio"
					aria-checked={filter === value}
					onclick={() => setFilter(value as PhotoFilter)}
				>
					{(label as () => string)()}
				</button>
			{/each}
		</div>
		{#if !selected && items.length}
			<Button variant="secondary" onclick={() => (selected = new SvelteSet())}>
				<CircleCheck size={16} aria-hidden="true" />{m.photos_select()}
			</Button>
		{/if}
	</div>
</div>

{#if selected}
	<div class="selection-bar" role="region" aria-label={m.photos_selection()}>
		<span class="count">{m.photos_selected({ count: selected.size })}</span>
		<div class="bar-actions">
			<Button variant="ghost" onclick={endSelection}>
				<X size={16} aria-hidden="true" />{m.cancel_button()}
			</Button>
			<Button disabled={!selected.size} loading={adding} onclick={addSelection}>
				<BookImage size={16} aria-hidden="true" />{target
					? m.album_add_to({ name: target.name })
					: m.album_add_button()}
			</Button>
		</div>
	</div>
{/if}
<p class="status" role="status">{status}</p>

{#if failed && items.length === 0}
	<Alert>{m.error_load()}</Alert>
{:else if !loading && items.length === 0 && page > 0}
	<section class="empty" aria-labelledby="empty-title">
		<span class="art" aria-hidden="true"><ImageIcon size={26} /></span>
		<h2 id="empty-title">{m.photos_empty_title()}</h2>
		<p>{filter === 'favorites' ? m.photos_favorites_empty() : m.photos_empty_body()}</p>
		{#if filter === 'all'}<a href={resolve('/(app)')}>{m.nav_files()}</a>{/if}
	</section>
{:else}
	<PhotoGrid
		{items}
		{token}
		{selected}
		onopen={(it) => (viewerIndex = items.indexOf(it))}
		ontogglefavorite={toggleFavorite}
		ontoggleselect={toggleSelect}
	/>
	{#if loading}<p class="muted center">{m.loading()}</p>{/if}
	<div bind:this={sentinel} aria-hidden="true"></div>
{/if}

<PhotoViewer
	{items}
	bind:index={viewerIndex}
	ontogglefavorite={toggleFavorite}
	actions={(it) => [
		{ label: m.album_add_button(), icon: BookImage, onselect: () => chooseAlbum([it.id]) }
	]}
/>
<AlbumPicker bind:open={pickerOpen} mediaIds={pickerIds} onadded={added} />

<style>
	.head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		flex-wrap: wrap;
		gap: var(--space-4);
		margin: var(--space-2) 0 var(--space-2);
	}
	h1 {
		font-size: var(--text-2xl);
		letter-spacing: -0.02em;
	}
	.tools {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: var(--space-2);
	}
	.chips {
		display: inline-flex;
		gap: var(--space-1);
		padding: 2px;
		border-radius: var(--radius-full);
		background: var(--color-surface-sunken);
	}
	.chips button {
		min-height: 2.5rem;
		padding: 0 var(--space-4);
		border: 0;
		border-radius: var(--radius-full);
		background: transparent;
		font: inherit;
		font-size: var(--text-sm);
		color: var(--color-text-muted);
		cursor: pointer;
	}
	.chips button[aria-checked='true'] {
		background: var(--color-surface);
		color: var(--color-text);
		font-weight: var(--weight-medium);
		box-shadow: var(--shadow-sm);
	}
	.status {
		min-height: var(--space-5);
		margin: 0 0 var(--space-2);
		color: var(--color-success);
		font-size: var(--text-sm);
	}
	.selection-bar {
		/* Under the app header, above month headings (the upload panel owns the bottom corner). */
		position: sticky;
		top: calc(4rem + var(--space-2));
		z-index: 4;
		display: flex;
		align-items: center;
		justify-content: space-between;
		flex-wrap: wrap;
		gap: var(--space-3);
		margin-bottom: var(--space-3);
		padding: var(--space-2) var(--space-2) var(--space-2) var(--space-5);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-full);
		background: var(--color-surface-raised);
		box-shadow: var(--shadow-lg);
	}
	.count {
		font-weight: var(--weight-medium);
	}
	.bar-actions {
		display: flex;
		gap: var(--space-2);
	}
	.muted {
		color: var(--color-text-muted);
	}
	.center {
		text-align: center;
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
	.art {
		display: grid;
		place-items: center;
		width: 3.5rem;
		height: 3.5rem;
		margin-bottom: var(--space-2);
		border-radius: var(--radius-full);
		background: var(--color-accent-subtle);
		color: var(--color-accent);
	}
	.empty h2 {
		font-size: var(--text-lg);
	}
	.empty p {
		margin: 0;
		max-width: 30rem;
		color: var(--color-text-muted);
	}
</style>
