<script lang="ts">
	import { CircleCheck, Heart, Image as ImageIcon, LoaderCircle, Play } from '@lucide/svelte';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import { formatDuration, monthKey, monthLabel, thumbUrl, type Media } from './api.js';
	import { justify } from './justify.js';

	let {
		items,
		token,
		grouped = true,
		selected = null,
		canFavorite = () => true,
		thumbOf,
		onopen,
		ontogglefavorite,
		ontoggleselect,
		onstartselect,
		onselectgroup
	}: {
		items: Media[];
		token: string;
		/** Month headings (timeline) or one continuous grid (albums). */
		grouped?: boolean;
		/** Selection mode when set: tiles toggle instead of opening. */
		selected?: ReadonlySet<string> | null;
		canFavorite?: (item: Media) => boolean;
		/** Thumbnail URL override (public album links). */
		thumbOf?: (item: Media) => string | null;
		onopen: (item: Media) => void;
		ontogglefavorite?: (item: Media) => void;
		/** shift: extend from the last toggled item (range selection). */
		ontoggleselect?: (item: Media, shift: boolean) => void;
		/** Starts selection mode with this item (the circle on a tile). */
		onstartselect?: (item: Media) => void;
		/** Selects or unselects a whole month. */
		onselectgroup?: (items: Media[]) => void;
	} = $props();

	const locale = getLocale();
	const GAP = 4;
	let width = $state(0);
	const target = $derived(width < 600 ? 140 : 220);

	const groups = $derived.by(() => {
		if (!grouped) return [{ key: '', items }];
		const out: { key: string; items: Media[] }[] = [];
		for (const it of items) {
			const key = monthKey(it.taken_at);
			if (out.at(-1)?.key !== key) out.push({ key, items: [] });
			out.at(-1)!.items.push(it);
		}
		return out;
	});

	const ratio = (it: Media) => (it.width && it.height ? it.width / it.height : 1);
	const nameOf = (it: Media) => it.expand?.node?.name ?? '';
</script>

<div class="grid" bind:clientWidth={width} class:selecting={selected}>
	{#each groups as group (group.key)}
		<section class="month" aria-labelledby={group.key ? `month-${group.key}` : undefined}>
			{#if group.key}
				<h2 id="month-{group.key}">
					<span>{monthLabel(group.key, locale)}</span>
					{#if selected && onselectgroup}
						{@const all = group.items.every((it) => selected?.has(it.id))}
						<button
							class="group-select"
							aria-pressed={all}
							onclick={() => onselectgroup(group.items)}
						>
							<CircleCheck size={16} aria-hidden="true" />{all
								? m.photos_unselect_month()
								: m.photos_select_month()}
						</button>
					{/if}
				</h2>
			{/if}
			{#each justify(group.items, ratio, width, target, GAP) as row, r (r)}
				<div class="row" style:height="{row.height}px">
					{#each row.items as it (it.id)}
						{@const name = nameOf(it)}
						{@const src = thumbOf ? thumbOf(it) : token ? thumbUrl(it, token) : null}
						{@const isSelected = selected?.has(it.id) ?? false}
						<div
							class="tile"
							class:fav={it.favorite}
							class:selected={isSelected}
							style:width="{ratio(it) * row.height}px"
						>
							<button
								class="open"
								aria-label={selected ? m.photo_select({ name }) : m.photo_open({ name })}
								aria-pressed={selected ? isSelected : undefined}
								onclick={(e) => (selected ? ontoggleselect?.(it, e.shiftKey) : onopen(it))}
							>
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
								{#if selected}
									<span class="check" aria-hidden="true"><CircleCheck size={22} /></span>
								{/if}
							</button>
							{#if !selected && onstartselect}
								<button
									class="start"
									aria-label={m.photo_select({ name })}
									onclick={() => onstartselect(it)}
								>
									<CircleCheck size={20} aria-hidden="true" />
								</button>
							{/if}
							{#if !selected && ontogglefavorite && canFavorite(it)}
								<button
									class="heart"
									aria-pressed={it.favorite}
									aria-label={it.favorite
										? m.photo_favorite_remove({ name })
										: m.photo_favorite_add({ name })}
									onclick={() => ontogglefavorite(it)}
								>
									<Heart
										size={18}
										aria-hidden="true"
										fill={it.favorite ? 'currentColor' : 'none'}
									/>
								</button>
							{/if}
						</div>
					{/each}
				</div>
			{/each}
		</section>
	{/each}
</div>

<style>
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
	.selecting .open {
		cursor: pointer;
	}
	.open img {
		display: block;
		width: 100%;
		height: 100%;
		object-fit: cover;
		transition: transform var(--duration-base) var(--ease-standard);
	}
	.grid:not(.selecting) .tile:hover .open img {
		transform: scale(1.03);
	}
	.selected .open img {
		transform: scale(0.9);
		border-radius: var(--radius-sm);
	}
	.selected {
		background: var(--color-accent-subtle);
	}
	.check {
		position: absolute;
		top: var(--space-2);
		left: var(--space-2);
		display: grid;
		place-items: center;
		border-radius: var(--radius-full);
		color: var(--color-on-stage);
		filter: drop-shadow(0 1px 2px var(--color-stage-scrim));
	}
	.selected .check {
		background: var(--color-accent);
		color: var(--color-accent-contrast);
		filter: none;
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
		filter: drop-shadow(0 1px 2px var(--color-stage-scrim));
		cursor: pointer;
		opacity: 0;
		transition: opacity var(--duration-fast) var(--ease-standard);
	}
	.tile:hover .heart,
	.tile:focus-within .heart,
	.tile.fav .heart,
	.tile:hover .start,
	.tile:focus-within .start {
		opacity: 1;
	}
	.start {
		position: absolute;
		top: var(--space-1);
		left: var(--space-1);
		display: grid;
		place-items: center;
		width: 2.5rem;
		height: 2.5rem;
		border: 0;
		border-radius: var(--radius-full);
		background: transparent;
		color: var(--color-on-stage);
		filter: drop-shadow(0 1px 2px var(--color-stage-scrim));
		cursor: pointer;
		opacity: 0;
		transition: opacity var(--duration-fast) var(--ease-standard);
	}
	.month h2 {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
	}
	.group-select {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
		min-height: 2.25rem;
		padding: 0 var(--space-3);
		border: 0;
		border-radius: var(--radius-full);
		background: transparent;
		color: var(--color-accent);
		font: inherit;
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		cursor: pointer;
	}
	.group-select:hover,
	.group-select[aria-pressed='true'] {
		background: var(--color-accent-subtle);
	}
	.tile.fav .heart {
		color: var(--color-favorite);
	}
	/* No hover on touch screens: only favorites show their heart, toggled from the viewer. */
	@media (hover: none) {
		.tile:not(.fav) .heart,
		.start {
			display: none;
		}
	}
</style>
