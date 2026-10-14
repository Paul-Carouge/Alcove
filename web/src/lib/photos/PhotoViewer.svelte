<script lang="ts">
	import {
		ChevronLeft,
		ChevronRight,
		Download,
		Heart,
		Info,
		Pause,
		Play,
		X,
		ZoomIn,
		ZoomOut
	} from '@lucide/svelte';
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
		downloadable = true,
		ontrash
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
		/** Moves the current item to the trash (Delete key). */
		ontrash?: (m: Media) => void;
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

	// Zoom and pan (wheel, double click, pinch, drag), reset for every item.
	const MAX_ZOOM = 5;
	let scale = $state(1);
	let tx = $state(0);
	let ty = $state(0);
	let stage = $state<HTMLDivElement>();
	$effect(() => {
		void item?.id;
		scale = 1;
		tx = 0;
		ty = 0;
	});
	function zoomAt(next: number, cx?: number, cy?: number) {
		next = Math.min(MAX_ZOOM, Math.max(1, next));
		if (next === 1) {
			scale = 1;
			tx = ty = 0;
			return;
		}
		// Keep the point under the cursor in place.
		if (stage && cx !== undefined && cy !== undefined) {
			const r = stage.getBoundingClientRect();
			const px = cx - r.left - r.width / 2;
			const py = cy - r.top - r.height / 2;
			tx = px - ((px - tx) * next) / scale;
			ty = py - ((py - ty) * next) / scale;
		}
		scale = next;
	}
	function onWheel(e: WheelEvent) {
		if (item?.kind === 'video') return;
		e.preventDefault();
		zoomAt(scale * (e.deltaY < 0 ? 1.15 : 1 / 1.15), e.clientX, e.clientY);
	}
	function onDblClick(e: MouseEvent) {
		if (item?.kind === 'video') return;
		zoomAt(scale > 1 ? 1 : 2.5, e.clientX, e.clientY);
	}

	// Pointers: one drags (pan when zoomed, swipe otherwise), two pinch.
	// Plain Map on purpose: pointer positions are bookkeeping, nothing renders from them.
	// eslint-disable-next-line svelte/prefer-svelte-reactivity
	const pointers = new Map<number, { x: number; y: number }>();
	let start = { x: 0, y: 0, tx: 0, ty: 0, dist: 0, scale: 1 };
	function onPointerDown(e: PointerEvent) {
		if (item?.kind === 'video' || (e.target as HTMLElement).closest('button')) return;
		(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
		pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
		const pts = [...pointers.values()];
		start = {
			x: e.clientX,
			y: e.clientY,
			tx,
			ty,
			dist: pts.length === 2 ? Math.hypot(pts[0]!.x - pts[1]!.x, pts[0]!.y - pts[1]!.y) : 0,
			scale
		};
	}
	function onPointerMove(e: PointerEvent) {
		if (!pointers.has(e.pointerId)) return;
		pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
		const pts = [...pointers.values()];
		if (pts.length === 2 && start.dist) {
			const d = Math.hypot(pts[0]!.x - pts[1]!.x, pts[0]!.y - pts[1]!.y);
			zoomAt(
				(start.scale * d) / start.dist,
				(pts[0]!.x + pts[1]!.x) / 2,
				(pts[0]!.y + pts[1]!.y) / 2
			);
		} else if (pts.length === 1 && scale > 1) {
			tx = start.tx + e.clientX - start.x;
			ty = start.ty + e.clientY - start.y;
		}
	}
	function onPointerUp(e: PointerEvent) {
		const was = pointers.size;
		pointers.delete(e.pointerId);
		if (was !== 1 || scale > 1) return;
		const dx = e.clientX - start.x;
		const dy = e.clientY - start.y;
		if (Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy) * 1.5) go(dx < 0 ? 1 : -1);
		else if (e.pointerType !== 'mouse' && dy > 100 && dy > Math.abs(dx) * 1.5) index = -1;
	}

	// Slideshow.
	const SLIDE_MS = 4000;
	let playing = $state(false);
	$effect(() => {
		if (!playing || !item || items.length < 2) return;
		const t = setTimeout(() => go(1), SLIDE_MS);
		return () => clearTimeout(t);
	});
	$effect(() => {
		if (!item) playing = false;
	});

	// The neighbours load in the background so the next picture shows at once.
	$effect(() => {
		if (!ready || index < 0 || items.length < 2) return;
		for (const step of [1, -1]) {
			const it = items[(index + step + items.length) % items.length];
			const src = it && it.kind !== 'video' ? preview(it) : null;
			if (src) new Image().src = src;
		}
	});

	function onKeydown(e: KeyboardEvent) {
		if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
		if (e.key === 'ArrowRight') go(1);
		else if (e.key === 'ArrowLeft') go(-1);
		else if (e.key === 'Home') index = 0;
		else if (e.key === 'End') index = items.length - 1;
		else if (e.key === 'i') showInfo = !showInfo;
		else if (e.key === 'f' && item && ontogglefavorite && canFavorite(item)) ontogglefavorite(item);
		else if ((e.key === 'Delete' || e.key === 'Backspace') && item && ontrash) ontrash(item);
		else if (e.key === ' ' && items.length > 1) playing = !playing;
		else if (e.key === '+' || e.key === '=') zoomAt(scale * 1.5);
		else if (e.key === '-') zoomAt(scale / 1.5);
		else if (e.key === '0') zoomAt(1);
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
			<span class="title">
				<span class="name">{node.name}</span>
				{#if items.length > 1}<span class="count">{index + 1} / {items.length}</span>{/if}
			</span>
			<div class="tools">
				{#if item.kind !== 'video'}
					<button
						class="icon-btn"
						aria-label={m.viewer_zoom_out()}
						title={m.viewer_zoom_out()}
						disabled={scale <= 1}
						onclick={() => zoomAt(scale / 1.5)}
					>
						<ZoomOut size={20} aria-hidden="true" />
					</button>
					<button
						class="icon-btn"
						aria-label={m.viewer_zoom_in()}
						title={m.viewer_zoom_in()}
						disabled={scale >= MAX_ZOOM}
						onclick={() => zoomAt(scale * 1.5)}
					>
						<ZoomIn size={20} aria-hidden="true" />
					</button>
				{/if}
				{#if items.length > 1}
					<button
						class="icon-btn"
						aria-pressed={playing}
						aria-label={playing ? m.viewer_slideshow_stop() : m.viewer_slideshow()}
						title={playing ? m.viewer_slideshow_stop() : m.viewer_slideshow()}
						onclick={() => (playing = !playing)}
					>
						{#if playing}<Pause size={20} aria-hidden="true" />{:else}<Play
								size={20}
								aria-hidden="true"
							/>{/if}
					</button>
				{/if}
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
			<!-- svelte-ignore a11y_no_static_element_interactions -->
			<div
				class="stage"
				class:zoomed={scale > 1}
				bind:this={stage}
				onwheel={onWheel}
				ondblclick={onDblClick}
				onpointerdown={onPointerDown}
				onpointermove={onPointerMove}
				onpointerup={onPointerUp}
				onpointercancel={onPointerUp}
			>
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
					{#key item.id}<img
							src={preview(item)}
							alt={node.name}
							draggable="false"
							style:transform="translate({tx}px, {ty}px) scale({scale})"
						/>{/key}
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
	.title {
		display: flex;
		align-items: baseline;
		gap: var(--space-3);
		min-width: 0;
	}
	.name {
		font-family: var(--font-display);
		font-size: var(--text-lg);
		font-weight: var(--weight-medium);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.count {
		flex: none;
		color: var(--color-on-stage-muted);
		font-size: var(--text-sm);
		font-variant-numeric: tabular-nums;
	}
	.icon-btn:disabled {
		opacity: 0.4;
		cursor: default;
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
		overflow: hidden;
		touch-action: none;
		user-select: none;
	}
	.stage.zoomed {
		cursor: grab;
	}
	.stage img {
		border-radius: var(--radius-sm);
		box-shadow: var(--shadow-lg);
		transition: transform var(--duration-fast) var(--ease-standard);
		will-change: transform;
		animation: fade var(--duration-base) var(--ease-standard);
	}
	.stage.zoomed img {
		transition: none;
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
		backdrop-filter: blur(var(--space-2));
		color: inherit;
		cursor: pointer;
		transition: background var(--duration-fast) var(--ease-standard);
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
		padding: var(--space-5);
		background: var(--color-stage-panel);
		border-left: 1px solid var(--color-stage-border);
		animation: fade var(--duration-base) var(--ease-standard);
	}
	h2 {
		font-size: var(--text-xl);
		margin-bottom: var(--space-3);
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
		letter-spacing: 0.08em;
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
		/* Phones: the name gets its own line so every tool stays on screen. */
		header {
			flex-wrap: wrap;
			gap: 0;
			padding: var(--space-2) var(--space-2) var(--space-1) var(--space-4);
		}
		.title {
			flex: 1 1 100%;
			min-height: 2rem;
			align-items: center;
		}
		.tools {
			flex: 1 1 100%;
			justify-content: space-between;
			gap: 0;
		}
		.nav {
			top: auto;
			bottom: var(--space-3);
			transform: none;
		}
	}
</style>
