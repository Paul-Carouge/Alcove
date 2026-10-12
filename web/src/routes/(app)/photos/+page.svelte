<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page as routePage } from '$app/state';
	import { untrack } from 'svelte';
	import { SvelteSet } from 'svelte/reactivity';
	import {
		BookImage,
		CircleCheck,
		Copy,
		Image as ImageIcon,
		MapPin,
		Heart,
		SlidersHorizontal,
		Trash2,
		X
	} from '@lucide/svelte';
	import { trashNode } from '#lib/drive/api.js';
	import { onMediaChange } from '#lib/drive/live.js';
	import { m } from '#lib/paraglide/messages.js';
	import {
		fileToken,
		getFacets,
		getMedia,
		isRefined,
		listMedia,
		setFavorite,
		type Facets,
		type Media,
		type PhotoFilter,
		type Refine
	} from '#lib/photos/api.js';
	import { addToAlbum, getAlbum } from '#lib/photos/albums.js';
	import AlbumPicker from '#lib/photos/AlbumPicker.svelte';
	import PhotoGrid from '#lib/photos/PhotoGrid.svelte';
	import PhotoViewer from '#lib/photos/PhotoViewer.svelte';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';

	let filter = $state<PhotoFilter>('all');
	let refine = $state<Refine>({});
	let filtersOpen = $state(false);
	let facets = $state<Facets | null>(null);
	const refineCount = $derived([refine.year, refine.camera, refine.located].filter(Boolean).length);
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
		!isRefined(refine) &&
		(filter === 'all' ||
			(filter === 'videos' && it.kind === 'video') ||
			(filter === 'favorites' && it.favorite));

	// Each view (filter, refinements) is a generation: answers for an older one are dropped.
	let generation = 0;

	async function loadMore(force = false) {
		if (loading && !force) return;
		const gen = generation;
		loading = true;
		try {
			const res = await listMedia(page + 1, filter, refine);
			if (gen !== generation) return;
			items = page === 0 ? res.items : [...items, ...res.items];
			total = res.totalItems;
			page = res.page;
			failed = false;
		} catch {
			if (gen === generation) failed = true;
		} finally {
			if (gen === generation) loading = false;
		}
	}

	function reload() {
		generation++;
		items = [];
		total = 0;
		page = 0;
		loadMore(true);
	}

	function setFilter(f: PhotoFilter) {
		if (f === filter) return;
		filter = f;
		reload();
	}

	function setRefine(next: Refine) {
		refine = next;
		reload();
	}

	// Facets change as new photos are processed: reload them while the panel is open.
	let facetsTimer: ReturnType<typeof setTimeout> | undefined;
	function refreshFacets() {
		clearTimeout(facetsTimer);
		facetsTimer = setTimeout(() => getFacets().then((f) => (facets = f)), 300);
	}

	function toggleFilters() {
		filtersOpen = !filtersOpen;
		if (filtersOpen) refreshFacets();
	}

	const cameraKey = (c?: { make: string; model: string }) =>
		c ? JSON.stringify([c.make, c.model]) : '';

	$effect(() => {
		fileToken().then((t) => (token = t));
		untrack(() => loadMore());
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
			if (filtersOpen) refreshFacets();
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
			clearTimeout(facetsTimer);
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

	/** Moves items to the trash (their drive files); they can be restored from the Trash page. */
	async function trash(list: Media[]) {
		const results = await Promise.allSettled(list.map((it) => trashNode(it.node)));
		const gone = new Set(
			list.filter((_, i) => results[i]!.status === 'fulfilled').map((it) => it.id)
		);
		items = items.filter((it) => !gone.has(it.id));
		total -= gone.size;
		status = m.photos_trashed({ count: gone.size });
	}

	async function trashSelection() {
		if (!selected?.size) return;
		const ids = selected;
		await trash(items.filter((it) => ids.has(it.id)));
		selected = null;
	}

	async function favoriteSelection() {
		if (!selected?.size) return;
		const ids = selected;
		const list = items.filter((it) => ids.has(it.id) && !it.favorite);
		await Promise.allSettled(list.map((it) => setFavorite(it.id, true)));
		for (const it of list) it.favorite = true;
		status = m.photos_favorited({ count: list.length });
		selected = null;
	}

	function showOnMap(id: string) {
		// eslint-disable-next-line svelte/no-navigation-without-resolve -- resolved path plus a query
		goto(`${resolve('/(app)/photos/map')}?focus=${encodeURIComponent(id)}`);
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
		<Button
			variant="secondary"
			aria-expanded={filtersOpen}
			aria-controls="photo-filters"
			onclick={toggleFilters}
		>
			<SlidersHorizontal size={16} aria-hidden="true" />{m.photos_filters()}
			{#if refineCount}<span class="badge">{refineCount}</span>{/if}
		</Button>
		{#if !selected && items.length}
			<Button variant="secondary" onclick={() => (selected = new SvelteSet())}>
				<CircleCheck size={16} aria-hidden="true" />{m.photos_select()}
			</Button>
		{/if}
		{#if !target}
			<a class="link-btn" href={resolve('/(app)/photos/map')}>
				<MapPin size={16} aria-hidden="true" />{m.map_title()}
			</a>
			<a class="link-btn" href={resolve('/(app)/photos/duplicates')}>
				<Copy size={16} aria-hidden="true" />{m.duplicates_title()}
			</a>
		{/if}
	</div>
</div>

{#if filtersOpen}
	<div class="filters" id="photo-filters" role="group" aria-label={m.photos_filters()}>
		<label>
			<span>{m.photos_filter_year()}</span>
			<select
				value={refine.year ?? ''}
				onchange={(e) => setRefine({ ...refine, year: Number(e.currentTarget.value) || undefined })}
			>
				<option value="">{m.photos_filter_any()}</option>
				{#each facets?.years ?? [] as y (y.year)}
					<option value={y.year}>{y.year} ({y.count})</option>
				{/each}
			</select>
		</label>
		<label>
			<span>{m.photos_filter_camera()}</span>
			<select
				value={cameraKey(refine.camera)}
				onchange={(e) => {
					const c = facets?.cameras.find((x) => cameraKey(x) === e.currentTarget.value);
					setRefine({ ...refine, camera: c ? { make: c.make, model: c.model } : undefined });
				}}
			>
				<option value="">{m.photos_filter_any()}</option>
				{#each facets?.cameras ?? [] as c (cameraKey(c))}
					<option value={cameraKey(c)}
						>{[c.make, c.model].filter(Boolean).join(' ')} ({c.count})</option
					>
				{/each}
			</select>
		</label>
		<label class="check">
			<input
				type="checkbox"
				checked={!!refine.located}
				onchange={(e) => setRefine({ ...refine, located: e.currentTarget.checked || undefined })}
			/>
			{m.photos_filter_located({ count: facets?.withLocation ?? 0 })}
		</label>
		{#if refineCount}
			<Button variant="ghost" onclick={() => setRefine({})}>{m.photos_filter_reset()}</Button>
		{/if}
	</div>
{/if}

{#if selected}
	<div class="selection-bar" role="region" aria-label={m.photos_selection()}>
		<span class="count">{m.photos_selected({ count: selected.size })}</span>
		<div class="bar-actions">
			<Button variant="ghost" onclick={endSelection}>
				<X size={16} aria-hidden="true" />{m.cancel_button()}
			</Button>
			{#if !target}
				<Button variant="ghost" disabled={!selected.size} onclick={favoriteSelection}>
					<Heart size={16} aria-hidden="true" />{m.photos_favorite_selected()}
				</Button>
				<Button variant="ghost" disabled={!selected.size} onclick={trashSelection}>
					<Trash2 size={16} aria-hidden="true" />{m.photos_trash_selected()}
				</Button>
			{/if}
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
		<p>
			{isRefined(refine)
				? m.photos_filter_none()
				: filter === 'favorites'
					? m.photos_favorites_empty()
					: m.photos_empty_body()}
		</p>
		{#if filter === 'all' && !isRefined(refine)}<a href={resolve('/(app)')}>{m.nav_files()}</a>{/if}
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
		{ label: m.album_add_button(), icon: BookImage, onselect: () => chooseAlbum([it.id]) },
		{
			label: m.photos_trash_one(),
			icon: Trash2,
			danger: true,
			onselect: () => {
				viewerIndex = -1;
				trash([it]);
			}
		},
		...(it.has_location
			? [
					{
						label: m.map_show(),
						icon: MapPin,
						onselect: () => showOnMap(it.id)
					}
				]
			: [])
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
	.badge {
		display: inline-grid;
		place-items: center;
		min-width: 1.25rem;
		height: 1.25rem;
		padding: 0 var(--space-1);
		border-radius: var(--radius-full);
		background: var(--color-accent);
		color: var(--color-accent-contrast);
		font-size: var(--text-xs);
	}
	.link-btn {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		min-height: 2.75rem;
		padding: 0 var(--space-3);
		border-radius: var(--radius-md);
		color: var(--color-text);
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		text-decoration: none;
	}
	.link-btn:hover {
		background: var(--color-surface-sunken);
	}
	.filters {
		display: flex;
		flex-wrap: wrap;
		align-items: flex-end;
		gap: var(--space-3) var(--space-5);
		margin-bottom: var(--space-3);
		padding: var(--space-4);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
	}
	.filters label {
		display: grid;
		gap: var(--space-1);
		font-size: var(--text-sm);
		color: var(--color-text-muted);
	}
	.filters label.check {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		min-height: 2.75rem;
		color: var(--color-text);
	}
	.filters input[type='checkbox'] {
		width: 1.25rem;
		height: 1.25rem;
		accent-color: var(--color-accent);
	}
	.filters select {
		min-width: 11rem;
		min-height: 2.75rem;
		padding: 0 var(--space-3);
		border: 1px solid var(--color-border-strong);
		border-radius: var(--radius-md);
		background: var(--color-surface);
		color: var(--color-text);
		font: inherit;
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
