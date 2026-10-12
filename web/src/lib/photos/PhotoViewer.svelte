<script lang="ts">
	import { ChevronLeft, ChevronRight, Download, Heart, Info, X } from '@lucide/svelte';
	import { formatSize } from '#lib/drive/format.js';
	import ActionsMenu, { type MenuAction } from '#lib/ui/ActionsMenu.svelte';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import {
		downloadMedia,
		fileToken,
		formatDuration,
		previewUrl,
		videoUrl,
		type Media
	} from './api.js';

	let {
		items,
		index = $bindable(-1),
		ontogglefavorite,
		canFavorite = () => true,
		actions = () => [],
		previewOf,
		videoOf,
		downloadable = true
	}: {
		items: Media[];
		index?: number;
		ontogglefavorite?: (m: Media) => void;
		canFavorite?: (m: Media) => boolean;
		/** Extra actions for the current item (add to album, set as cover…). */
		actions?: (m: Media) => MenuAction[];
		/** URL overrides for public album links (no account, no file token). */
		previewOf?: (m: Media) => string | null;
		videoOf?: (m: Media) => string | null;
		downloadable?: boolean;
	} = $props();

	let dialog: HTMLDialogElement;
	let token = $state('');
	// Details open by default where there is room beside the picture.
	let showInfo = $state(!matchMedia('(max-width: 900px)').matches);
	const locale = getLocale();

	const item = $derived(index >= 0 ? items[index] : undefined);
	const node = $derived(item?.expand?.node);

	$effect(() => {
		if (item && !dialog.open) dialog.showModal();
		if (!item && dialog.open) dialog.close();
	});
	$effect(() => {
		if (item && !previewOf) fileToken().then((t) => (token = t));
	});
	const preview = (it: Media) => (previewOf ? previewOf(it) : token ? previewUrl(it, token) : null);
	const video = (it: Media) => (videoOf ? videoOf(it) : token ? videoUrl(it, token) : null);
	const ready = $derived(!!previewOf || !!token);

	function go(step: number) {
		if (items.length > 1) index = (index + step + items.length) % items.length;
	}
	function onKeydown(e: KeyboardEvent) {
		if (e.key === 'ArrowRight') go(1);
		else if (e.key === 'ArrowLeft') go(-1);
		else if (e.key === 'i') showInfo = !showInfo;
		else return;
		e.preventDefault();
	}

	const takenLabel = (iso: string) =>
		new Intl.DateTimeFormat(locale, { dateStyle: 'full', timeStyle: 'short' }).format(
			new Date(iso.replace(' ', 'T'))
		);
	const camera = (m: Media) => [m.camera_make, m.camera_model].filter(Boolean).join(' ');
	const osm = (m: Media) =>
		`https://www.openstreetmap.org/?mlat=${m.lat}&mlon=${m.lon}#map=15/${m.lat}/${m.lon}`;
</script>

<dialog
	bind:this={dialog}
	class="viewer"
	aria-label={node?.name ?? ''}
	onclose={() => (index = -1)}
	onkeydown={onKeydown}
>
	{#if item && node}
		<header>
			<span class="name">{node.name}</span>
			<div class="tools">
				{#if ontogglefavorite && canFavorite(item)}<button
						class="icon-btn"
						class:fav={item.favorite}
						aria-pressed={item.favorite}
						aria-label={item.favorite
							? m.photo_favorite_remove({ name: node.name })
							: m.photo_favorite_add({ name: node.name })}
						onclick={() => ontogglefavorite?.(item)}
					>
						<Heart size={20} aria-hidden="true" fill={item.favorite ? 'currentColor' : 'none'} />
					</button>{/if}
				<button
					class="icon-btn"
					aria-pressed={showInfo}
					aria-label={m.photo_info_toggle()}
					title={m.photo_info()}
					onclick={() => (showInfo = !showInfo)}
				>
					<Info size={20} aria-hidden="true" />
				</button>
				{#if downloadable}
					<button
						class="icon-btn"
						aria-label={m.action_download()}
						title={m.action_download()}
						onclick={() => downloadMedia(item)}
					>
						<Download size={20} aria-hidden="true" />
					</button>
				{/if}
				{#if actions(item).length}
					<ActionsMenu label={m.photo_more({ name: node.name })} actions={actions(item)} />
				{/if}
				<button
					class="icon-btn"
					aria-label={m.viewer_close()}
					title={m.viewer_close()}
					onclick={() => (index = -1)}
				>
					<X size={20} aria-hidden="true" />
				</button>
			</div>
		</header>

		<div class="body" class:with-info={showInfo}>
			<div class="stage">
				{#if items.length > 1}
					<button class="nav prev" aria-label={m.viewer_prev()} onclick={() => go(-1)}
						><ChevronLeft size={24} aria-hidden="true" /></button
					>
				{/if}
				{#if !ready}
					<span class="muted">{m.loading()}</span>
				{:else if item.kind === 'video' && video(item)}
					{#key item.id}
						<!-- svelte-ignore a11y_media_has_caption -->
						<video
							src={video(item)}
							poster={preview(item) ?? undefined}
							controls
							autoplay
							playsinline
						></video>
					{/key}
				{:else if preview(item)}
					{#key item.id}<img src={preview(item)} alt={node.name} />{/key}
				{:else}
					<p class="muted">{m.photo_no_preview()}</p>
				{/if}
				{#if items.length > 1}
					<button class="nav next" aria-label={m.viewer_next()} onclick={() => go(1)}
						><ChevronRight size={24} aria-hidden="true" /></button
					>
				{/if}
			</div>

			{#if showInfo}
				<aside class="info" aria-label={m.photo_info()}>
					<h2>{m.photo_info()}</h2>
					<dl>
						<dt>{m.photo_taken()}</dt>
						<dd>{takenLabel(item.taken_at)}</dd>
						<dt>{m.photo_file()}</dt>
						<dd>
							{node.name}{#if node.size}<br /><span class="muted"
									>{formatSize(node.size, locale)}</span
								>{/if}
						</dd>
						{#if item.width}
							<dt>{m.photo_dimensions()}</dt>
							<dd>{item.width} × {item.height}</dd>
						{/if}
						{#if item.kind === 'video' && item.duration}
							<dt>{m.photo_duration()}</dt>
							<dd>{formatDuration(item.duration)}</dd>
						{/if}
						{#if camera(item)}
							<dt>{m.photo_camera()}</dt>
							<dd>{camera(item)}</dd>
						{/if}
						{#if item.lens}
							<dt>{m.photo_lens()}</dt>
							<dd>{item.lens}</dd>
						{/if}
						{#if item.exposure}
							<dt>{m.photo_settings()}</dt>
							<dd>{item.exposure}</dd>
						{/if}
						{#if item.has_location}
							<dt>{m.photo_location()}</dt>
							<dd>
								{item.lat.toFixed(5)}, {item.lon.toFixed(5)}<br />
								<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- external map link -->
								<a href={osm(item)} target="_blank" rel="noopener noreferrer">{m.photo_map()}</a>
							</dd>
						{/if}
					</dl>
				</aside>
			{/if}
		</div>
	{/if}
</dialog>

<style>
	.viewer {
		/* Always dark: shared components (menus) read these semantic tokens. */
		--color-text: var(--color-on-stage);
		--color-text-muted: var(--color-on-stage-muted);
		--color-surface-raised: var(--color-stage-panel);
		--color-surface-sunken: var(--color-stage-control);
		--color-border: var(--color-stage-border);
		width: 100vw;
		height: 100dvh;
		max-width: none;
		max-height: none;
		margin: 0;
		padding: 0;
		border: 0;
		background: var(--color-stage);
		color: var(--color-on-stage);
	}
	.viewer[open] {
		display: flex;
		flex-direction: column;
		animation: fade var(--duration-base) var(--ease-standard);
	}
	@keyframes fade {
		from {
			opacity: 0;
		}
	}
	header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
		padding: var(--space-2) var(--space-3) var(--space-2) var(--space-5);
	}
	.name {
		font-weight: var(--weight-medium);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.tools {
		display: flex;
		gap: var(--space-1);
	}
	.icon-btn {
		display: grid;
		place-items: center;
		width: calc(var(--space-7) - var(--space-1));
		height: calc(var(--space-7) - var(--space-1));
		border: 0;
		border-radius: var(--radius-md);
		background: transparent;
		color: inherit;
		cursor: pointer;
	}
	.icon-btn:hover,
	.icon-btn[aria-pressed='true'] {
		background: var(--color-stage-control);
	}
	.icon-btn.fav {
		color: var(--color-favorite);
	}
	.body {
		flex: 1;
		min-height: 0;
		display: grid;
		grid-template-columns: 1fr;
	}
	.body.with-info {
		grid-template-columns: 1fr 20rem;
	}
	.stage {
		position: relative;
		min-height: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: var(--space-3) var(--space-8) var(--space-5);
	}
	img,
	video {
		max-width: 100%;
		max-height: 100%;
		object-fit: contain;
	}
	.muted {
		color: var(--color-on-stage-muted);
	}
	.nav {
		position: absolute;
		top: 50%;
		transform: translateY(-50%);
		display: grid;
		place-items: center;
		width: 3rem;
		height: 3rem;
		border: 0;
		border-radius: var(--radius-full);
		background: var(--color-stage-control);
		color: inherit;
		cursor: pointer;
	}
	.nav:hover {
		background: color-mix(in srgb, var(--color-stage-control), var(--color-on-stage) 12%);
	}
	.prev {
		left: var(--space-3);
	}
	.next {
		right: var(--space-3);
	}
	.info {
		overflow-y: auto;
		padding: var(--space-4) var(--space-5);
		background: var(--color-stage-panel);
		border-left: 1px solid var(--color-stage-border);
	}
	h2 {
		font-size: var(--text-md);
		margin-bottom: var(--space-4);
	}
	dl {
		display: grid;
		gap: var(--space-1);
		margin: 0;
		font-size: var(--text-sm);
	}
	dt {
		margin-top: var(--space-3);
		color: var(--color-on-stage-muted);
		font-size: var(--text-xs);
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}
	dd {
		margin: 0;
		overflow-wrap: anywhere;
	}
	a {
		color: var(--color-on-stage-link);
	}
	@media (max-width: 900px) {
		.body.with-info {
			grid-template-columns: 1fr;
			grid-template-rows: 1fr auto;
		}
		.info {
			max-height: 40dvh;
			border-left: 0;
			border-top: 1px solid var(--color-stage-border);
		}
		.stage {
			padding: var(--space-2);
		}
		.nav {
			top: auto;
			bottom: var(--space-3);
			transform: none;
		}
	}
</style>
