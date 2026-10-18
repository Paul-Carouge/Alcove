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
		Download,
		Image as ImageIcon,
		MapPin,
		Heart,
		Import,
		SlidersHorizontal,
		Trash2
	} from '@lucide/svelte';
	import { trashNode } from '#lib/drive/api.js';
	import { onMediaChange } from '#lib/drive/live.js';
	import { downloadZip } from '#lib/drive/zip.js';
	import { m } from '#lib/paraglide/messages.js';
	import {
		fileToken,
		getFacets,
		getMedia,
		getMemories,
		monthKey,
		thumbUrl,
		isRefined,
		listMedia,
		PAGE_SIZE,
		setFavorite,
		type Facets,
		type Media,
		type Memory,
		type PhotoFilter,
		type Refine
	} from '#lib/photos/api.js';
	import { addToAlbum, getAlbum } from '#lib/photos/albums.js';
	import AlbumPicker from '#lib/photos/AlbumPicker.svelte';
	import PhotoGrid from '#lib/photos/PhotoGrid.svelte';
	import PhotoViewer from '#lib/photos/PhotoViewer.svelte';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import EmptyState from '#lib/ui/EmptyState.svelte';
	import Select from '#lib/ui/Select.svelte';
	import SelectionBar from '#lib/ui/SelectionBar.svelte';

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

	// Memories ("1 year ago today") above the timeline.
	let memories = $state<Memory[]>([]);
	let memoryItems = $state<Media[]>([]);
	let memoryIndex = $state(-1);
	const showMemories = $derived(
		filter === 'all' && !isRefined(refine) && !selected && !target && memories.length > 0
	);
	function openMemory(mem: Memory) {
		memoryItems = mem.items;
		memoryIndex = 0;
	}

	// Years of the loaded timeline, to jump to.
	const years = $derived.by(() => {
		const out: { year: string; key: string }[] = [];
		for (const it of items) {
			const key = monthKey(it.taken_at);
			const year = key.slice(0, 4);
			if (out.at(-1)?.year !== year) out.push({ year, key });
		}
		return out;
	});
	function jumpTo(key: string) {
		document.getElementById(`month-${key}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
	}

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
			if (res.totalItems >= 0) total = res.totalItems;
			// A short page is the end, whatever the first page counted.
			if (res.items.length < PAGE_SIZE) total = items.length;
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
		getMemories()
			.then((list) => (memories = list))
			.catch(() => {});
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

	// Shift extends the selection from the last photo toggled, like file managers.
	let anchor = '';
	function toggleSelect(item: Media, shift = false) {
		if (!selected) return;
		const from = items.findIndex((x) => x.id === anchor);
		const to = items.indexOf(item);
		if (shift && from >= 0 && to >= 0) {
			const [a, b] = from < to ? [from, to] : [to, from];
			for (const it of items.slice(a, b + 1)) selected.add(it.id);
		} else if (selected.has(item.id)) selected.delete(item.id);
		else selected.add(item.id);
		anchor = item.id;
	}

	function startSelect(item: Media) {
		selected = new SvelteSet([item.id]);
		anchor = item.id;
	}

	function selectGroup(group: Media[]) {
		if (!selected) return;
		const all = group.every((it) => selected!.has(it.id));
		for (const it of group) {
			if (all) selected.delete(it.id);
			else selected.add(it.id);
		}
	}

	let zipping = $state(false);
	async function downloadSelection() {
		if (!selected?.size) return;
		const ids = selected;
		zipping = true;
		status = m.zip_preparing();
		try {
			await downloadZip(
				{ nodes: items.filter((it) => ids.has(it.id)).map((it) => it.node) },
				'Photos'
			);
			status = '';
		} catch {
			status = m.zip_failed();
		} finally {
			zipping = false;
		}
	}

	/** From the viewer (Delete key or menu): the next photo shows. */
	async function trashFromViewer(it: Media) {
		const at = viewerIndex;
		await trash([it]);
		viewerIndex = items.length ? Math.min(at, items.length - 1) : -1;
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
			<a class="link-btn" href={resolve('/(app)/photos/import')} title={m.import_title()}>
				<Import size={16} aria-hidden="true" />{m.import_link()}
			</a>
		{/if}
	</div>
</div>

{#if filtersOpen}
	<div class="filters" id="photo-filters" role="group" aria-label={m.photos_filters()}>
		<div class="field">
			<span id="year-label">{m.photos_filter_year()}</span>
			<Select
				labelledby="year-label"
				value={String(refine.year ?? '')}
				options={[
					{ value: '', label: m.photos_filter_any() },
					...(facets?.years ?? []).map((y) => ({
						value: String(y.year),
						label: `${y.year} (${y.count})`
					}))
				]}
				onchange={(v) => setRefine({ ...refine, year: Number(v) || undefined })}
			/>
		</div>
		<div class="field">
			<span id="camera-label">{m.photos_filter_camera()}</span>
			<Select
				labelledby="camera-label"
				value={cameraKey(refine.camera)}
				options={[
					{ value: '', label: m.photos_filter_any() },
					...(facets?.cameras ?? []).map((c) => ({
						value: cameraKey(c),
						label: `${[c.make, c.model].filter(Boolean).join(' ')} (${c.count})`
					}))
				]}
				onchange={(v) => {
					const c = facets?.cameras.find((x) => cameraKey(x) === v);
					setRefine({ ...refine, camera: c ? { make: c.make, model: c.model } : undefined });
				}}
			/>
		</div>
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

<p class="status" role="status">{status}</p>

{#if showMemories}
	<section class="memories" aria-labelledby="memories-title">
		<h2 id="memories-title">{m.photos_memories()}</h2>
		<ul>
			{#each memories as mem (mem.year)}
				{@const cover = mem.items[0]}
				{@const when = m.photos_years_ago({ count: mem.yearsAgo })}
				<li>
					<button
						class="memory"
						aria-label={m.photos_memory_open({ when })}
						onclick={() => openMemory(mem)}
					>
						{#if cover && token}<img src={thumbUrl(cover, token)} alt="" loading="lazy" />{/if}
						<span class="memory-label">
							<strong>{when}</strong>
							<span>{mem.year} · {mem.items.length}</span>
						</span>
					</button>
				</li>
			{/each}
		</ul>
	</section>
{/if}

{#if years.length > 1 && !selected}
	<nav class="years" aria-label={m.photos_jump()}>
		{#each years as y (y.year)}
			<button onclick={() => jumpTo(y.key)}>{y.year}</button>
		{/each}
	</nav>
{/if}

{#if failed && items.length === 0}
	<Alert>{m.error_load()}</Alert>
{:else if !loading && items.length === 0 && page > 0}
	<EmptyState icon={ImageIcon} title={m.photos_empty_title()}>
		{isRefined(refine)
			? m.photos_filter_none()
			: filter === 'favorites'
				? m.photos_favorites_empty()
				: m.photos_empty_body()}
		{#snippet action()}
			{#if filter === 'all' && !isRefined(refine)}<a
					class="link-btn outline"
					href={resolve('/(app)')}>{m.nav_files()}</a
				>{/if}
		{/snippet}
	</EmptyState>
{:else}
	<PhotoGrid
		{items}
		{token}
		{selected}
		onopen={(it) => (viewerIndex = items.indexOf(it))}
		ontogglefavorite={toggleFavorite}
		ontoggleselect={toggleSelect}
		onstartselect={target ? undefined : startSelect}
		onselectgroup={selectGroup}
	/>
	{#if loading}<p class="muted center">{m.loading()}</p>{/if}
	<div bind:this={sentinel} aria-hidden="true"></div>
{/if}

<SelectionBar
	open={!!selected}
	label={m.photos_selected({ count: selected?.size ?? 0 })}
	onclear={endSelection}
	clearLabel={target ? m.cancel_button() : m.clear_selection()}
	actions={[
		...(target
			? []
			: [
					{
						label: m.photos_favorite_selected(),
						icon: Heart,
						disabled: !selected?.size,
						onclick: favoriteSelection
					},
					{
						label: m.photos_download_selected(),
						icon: Download,
						disabled: !selected?.size,
						loading: zipping,
						onclick: downloadSelection
					},
					{
						label: m.photos_trash_selected(),
						icon: Trash2,
						disabled: !selected?.size,
						onclick: trashSelection
					}
				]),
		{
			label: target ? m.album_add_to({ name: target.name }) : m.album_add_button(),
			icon: BookImage,
			primary: true,
			disabled: !selected?.size,
			loading: adding,
			onclick: addSelection
		}
	]}
/>

<PhotoViewer
	{items}
	bind:index={viewerIndex}
	ontogglefavorite={toggleFavorite}
	ontrash={trashFromViewer}
	actions={(it) => [
		{ label: m.album_add_button(), icon: BookImage, onselect: () => chooseAlbum([it.id]) },
		{
			label: m.photos_trash_one(),
			icon: Trash2,
			danger: true,
			onselect: () => trashFromViewer(it)
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
<PhotoViewer items={memoryItems} bind:index={memoryIndex} ontogglefavorite={toggleFavorite} />
<AlbumPicker bind:open={pickerOpen} mediaIds={pickerIds} onadded={added} />

<style>
	.head {
		display: flex;
		align-items: flex-end;
		justify-content: space-between;
		flex-wrap: wrap;
		gap: var(--space-4);
		min-height: 3.5rem;
		margin: 0 0 var(--space-4);
	}
	.tools {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: var(--space-2);
	}
	/* Phones: one row that scrolls sideways instead of three wrapped rows. */
	@media (max-width: 600px) {
		.head {
			flex-direction: column;
			align-items: stretch;
			/* A wrapping column would stretch to its widest child, the scrolling tools row. */
			flex-wrap: nowrap;
		}
		.tools {
			flex-wrap: nowrap;
			overflow-x: auto;
			scrollbar-width: none;
			margin-inline: calc(-1 * var(--space-4));
			padding: var(--space-1) var(--space-4);
		}
		.tools > :global(*) {
			flex-shrink: 0;
		}
	}
	.chips {
		display: inline-flex;
		gap: var(--space-1);
		padding: var(--space-1);
		border-radius: var(--radius-full);
		background: var(--color-surface-sunken);
	}
	.chips button {
		min-height: 2.25rem;
		padding: 0 var(--space-4);
		border: 0;
		border-radius: var(--radius-full);
		background: transparent;
		font: inherit;
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		color: var(--color-text-muted);
		cursor: pointer;
		transition:
			background var(--duration-fast) var(--ease-standard),
			color var(--duration-fast) var(--ease-standard);
	}
	.chips button:hover {
		color: var(--color-text);
	}
	.chips button[aria-checked='true'] {
		background: var(--color-surface);
		color: var(--color-text);
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
		transition: background var(--duration-fast) var(--ease-standard);
	}
	.link-btn:hover {
		background: color-mix(in srgb, var(--color-text) 6%, transparent);
	}
	.link-btn.outline {
		padding: 0 var(--space-4);
		border: 1px solid var(--color-border);
		background: var(--color-surface);
		box-shadow: var(--shadow-sm);
	}
	.filters {
		display: flex;
		flex-wrap: wrap;
		align-items: flex-end;
		gap: var(--space-3) var(--space-5);
		margin-bottom: var(--space-4);
		padding: var(--space-4) var(--space-5);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
		box-shadow: var(--shadow-sm);
		animation: rise var(--duration-base) var(--ease-emphasized);
	}
	@keyframes rise {
		from {
			opacity: 0;
			transform: translateY(calc(-1 * var(--space-1)));
		}
	}
	.filters .field {
		display: grid;
		gap: var(--space-2);
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		color: var(--color-text-muted);
	}
	.filters label.check {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		min-height: 2.75rem;
		font-size: var(--text-sm);
		color: var(--color-text);
	}
	.filters input[type='checkbox'] {
		width: 1.25rem;
		height: 1.25rem;
	}
	.filters .field :global(.select) {
		min-width: 11rem;
	}
	.status {
		min-height: var(--space-5);
		margin: 0 0 var(--space-2);
		color: var(--color-success);
		font-size: var(--text-sm);
	}
	.muted {
		color: var(--color-text-muted);
	}
	.center {
		text-align: center;
	}
	.memories {
		margin-bottom: var(--space-6);
	}
	.memories h2 {
		margin: 0 0 var(--space-3);
		font-size: var(--text-xl);
	}
	.memories ul {
		display: flex;
		gap: var(--space-3);
		margin: 0;
		padding: 0 0 var(--space-2);
		overflow-x: auto;
		list-style: none;
		scrollbar-width: thin;
		scroll-snap-type: x proximity;
	}
	.memories li {
		scroll-snap-align: start;
	}
	.memory {
		position: relative;
		display: block;
		width: 11rem;
		height: 14rem;
		padding: 0;
		overflow: hidden;
		border: 0;
		border-radius: var(--radius-lg);
		background: var(--color-surface-sunken);
		box-shadow: var(--shadow-md);
		cursor: pointer;
		transition: transform var(--duration-base) var(--ease-standard);
	}
	.memory:hover {
		transform: translateY(calc(-1 * var(--space-1)));
	}
	.memory img {
		width: 100%;
		height: 100%;
		object-fit: cover;
		transition: transform var(--duration-slow) var(--ease-standard);
	}
	.memory:hover img {
		transform: scale(1.04);
	}
	.memory-label {
		position: absolute;
		inset: auto 0 0;
		display: grid;
		gap: var(--space-0);
		padding: var(--space-7) var(--space-4) var(--space-4);
		background: linear-gradient(transparent, var(--color-stage-scrim));
		color: var(--color-on-stage);
		font-size: var(--text-xs);
		text-align: left;
	}
	.memory-label strong {
		font-family: var(--font-display);
		font-size: var(--text-lg);
		font-weight: var(--weight-medium);
		line-height: var(--leading-tight);
	}
	.years {
		position: fixed;
		right: var(--space-3);
		top: 50%;
		z-index: 5;
		display: grid;
		gap: var(--space-0);
		padding: var(--space-1);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-full);
		background: color-mix(in srgb, var(--color-surface) 90%, transparent);
		backdrop-filter: blur(var(--space-2));
		box-shadow: var(--shadow-md);
		transform: translateY(-50%);
	}
	.years button {
		min-width: 3.25rem;
		min-height: 2.25rem;
		padding: 0 var(--space-2);
		border: 0;
		border-radius: var(--radius-full);
		background: transparent;
		color: var(--color-text-muted);
		font: inherit;
		font-size: var(--text-xs);
		font-weight: var(--weight-medium);
		font-variant-numeric: tabular-nums;
		cursor: pointer;
	}
	.years button:hover {
		background: var(--color-accent-subtle);
		color: var(--color-accent);
	}
	@media (max-width: 900px) {
		.years {
			display: none;
		}
	}
	@media (prefers-reduced-motion: reduce) {
		.memory:hover,
		.memory:hover img {
			transform: none;
		}
	}
</style>
