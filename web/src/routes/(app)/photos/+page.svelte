<script lang="ts">
	import { resolve } from '$app/paths';
	import { untrack } from 'svelte';
	import { Heart, Image as ImageIcon, LoaderCircle, Play } from '@lucide/svelte';
	import { onMediaChange } from '#lib/drive/live.js';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import {
		fileToken,
		formatDuration,
		getMedia,
		listMedia,
		monthKey,
		monthLabel,
		setFavorite,
		thumbUrl,
		type Media,
		type PhotoFilter
	} from '#lib/photos/api.js';
	import { justify } from '#lib/photos/justify.js';
	import PhotoViewer from '#lib/photos/PhotoViewer.svelte';
	import Alert from '#lib/ui/Alert.svelte';

	const locale = getLocale();
	const GAP = 4;

	let filter = $state<PhotoFilter>('all');
	let items = $state<Media[]>([]);
	let total = $state(0);
	let page = $state(0);
	let loading = $state(false);
	let failed = $state(false);
	let token = $state('');
	let width = $state(0);
	let viewerIndex = $state(-1);
	let sentinel = $state<HTMLDivElement>();

	const target = $derived(width < 600 ? 140 : 220);
	const hasMore = $derived(items.length < total);
	const months = $derived.by(() => {
		const groups: { key: string; items: Media[] }[] = [];
		for (const it of items) {
			const key = monthKey(it.taken_at);
			if (groups.at(-1)?.key !== key) groups.push({ key, items: [] });
			groups.at(-1)!.items.push(it);
		}
		return groups;
	});

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

	const ratio = (it: Media) => (it.width && it.height ? it.width / it.height : 1);
	const open = (it: Media) => (viewerIndex = items.indexOf(it));
</script>

<svelte:head>
	<title>{m.photos_title()}</title>
</svelte:head>

<div class="head">
	<h1>{m.photos_title()}</h1>
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
</div>

<div class="timeline" bind:clientWidth={width}>
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
		{#each months as group (group.key)}
			<section class="month" aria-labelledby="month-{group.key}">
				<h2 id="month-{group.key}">{monthLabel(group.key, locale)}</h2>
				{#each justify(group.items, ratio, width, target, GAP) as row, r (r)}
					<div class="row" style:height="{row.height}px">
						{#each row.items as it (it.id)}
							{@const name = it.expand?.node?.name ?? ''}
							{@const src = token ? thumbUrl(it, token) : null}
							<div class="tile" class:fav={it.favorite} style:width="{ratio(it) * row.height}px">
								<button class="open" aria-label={m.photo_open({ name })} onclick={() => open(it)}>
									{#if src}
										<img {src} alt="" loading="lazy" decoding="async" />
									{:else}
										<span class="placeholder">
											{#if it.status === 'pending'}<LoaderCircle
													size={20}
													aria-label={m.photos_processing()}
												/>{:else}<ImageIcon size={20} aria-hidden="true" />{/if}
										</span>
									{/if}
									{#if it.kind === 'video'}
										<span class="badge"
											><Play size={12} aria-hidden="true" fill="currentColor" />{formatDuration(
												it.duration
											)}</span
										>
									{/if}
								</button>
								<button
									class="heart"
									aria-pressed={it.favorite}
									aria-label={it.favorite
										? m.photo_favorite_remove({ name })
										: m.photo_favorite_add({ name })}
									onclick={() => toggleFavorite(it)}
								>
									<Heart
										size={18}
										aria-hidden="true"
										fill={it.favorite ? 'currentColor' : 'none'}
									/>
								</button>
							</div>
						{/each}
					</div>
				{/each}
			</section>
		{/each}
		{#if loading}<p class="muted center">{m.loading()}</p>{/if}
		<div bind:this={sentinel} aria-hidden="true"></div>
	{/if}
</div>

<PhotoViewer {items} bind:index={viewerIndex} ontogglefavorite={toggleFavorite} />

<style>
	.head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		flex-wrap: wrap;
		gap: var(--space-4);
		margin: var(--space-2) 0 var(--space-4);
	}
	h1 {
		font-size: var(--text-2xl);
		letter-spacing: -0.02em;
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
	.month {
		margin-bottom: var(--space-5);
	}
	.month h2 {
		position: sticky;
		top: 4rem;
		z-index: 2;
		margin: 0 0 var(--space-2);
		padding: var(--space-2) 0;
		font-size: var(--text-md);
		background: color-mix(in srgb, var(--color-bg) 92%, transparent);
	}
	.row {
		display: flex;
		gap: 4px;
		margin-bottom: 4px;
	}
	.tile {
		position: relative;
		flex: none;
		overflow: hidden;
		border-radius: var(--radius-sm);
		background: var(--color-surface-sunken);
	}
	.open {
		display: block;
		width: 100%;
		height: 100%;
		padding: 0;
		border: 0;
		background: none;
		cursor: zoom-in;
	}
	.open img {
		display: block;
		width: 100%;
		height: 100%;
		object-fit: cover;
		transition: transform var(--duration-base) var(--ease-standard);
	}
	.tile:hover .open img {
		transform: scale(1.03);
	}
	.placeholder {
		display: grid;
		place-items: center;
		width: 100%;
		height: 100%;
		color: var(--color-text-muted);
	}
	.placeholder :global(.lucide-loader-circle) {
		animation: spin 1s linear infinite;
	}
	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}
	.badge {
		position: absolute;
		right: var(--space-2);
		bottom: var(--space-2);
		display: inline-flex;
		align-items: center;
		gap: 3px;
		padding: 1px var(--space-2);
		border-radius: var(--radius-full);
		background: var(--color-stage-scrim);
		color: var(--color-on-stage);
		font-size: var(--text-xs);
		font-variant-numeric: tabular-nums;
	}
	.heart {
		position: absolute;
		top: var(--space-1);
		right: var(--space-1);
		display: grid;
		place-items: center;
		width: 2.5rem;
		height: 2.5rem;
		border: 0;
		border-radius: var(--radius-full);
		background: transparent;
		color: var(--color-on-stage);
		filter: drop-shadow(var(--shadow-sm));
		cursor: pointer;
		opacity: 0;
		transition: opacity var(--duration-fast) var(--ease-standard);
	}
	.tile:hover .heart,
	.tile:focus-within .heart,
	.tile.fav .heart {
		opacity: 1;
	}
	.tile.fav .heart {
		color: var(--color-favorite);
	}
	/* No hover on touch screens: only favorites show their heart, toggled from the viewer. */
	@media (hover: none) {
		.tile:not(.fav) .heart {
			display: none;
		}
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
