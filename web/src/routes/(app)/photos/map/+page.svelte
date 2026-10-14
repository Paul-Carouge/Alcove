<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { ArrowLeft, MapPin } from '@lucide/svelte';
	import 'leaflet/dist/leaflet.css';
	import type * as Leaflet from 'leaflet';
	import { m } from '#lib/paraglide/messages.js';
	import { pb } from '#lib/pb.js';
	import {
		fileToken,
		getMapConfig,
		getMediaMany,
		listLocations,
		setFavorite,
		type Location,
		type Media
	} from '#lib/photos/api.js';
	import { cluster } from '#lib/photos/cluster.js';
	import PhotoViewer from '#lib/photos/PhotoViewer.svelte';
	import Alert from '#lib/ui/Alert.svelte';

	let container = $state<HTMLDivElement>();
	let count = $state<number | null>(null);
	let failed = $state(false);
	let viewerItems = $state<Media[]>([]);
	let viewerIndex = $state(-1);

	const MAX_VIEWER = 200;
	const CELL = 72;

	function css(name: string) {
		return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
	}

	async function openItems(ids: string[], focus?: string) {
		const items = await getMediaMany(ids.slice(0, MAX_VIEWER));
		viewerItems = items;
		viewerIndex = Math.max(0, focus ? items.findIndex((it) => it.id === focus) : 0);
	}

	async function toggleFavorite(item: Media) {
		const next = !item.favorite;
		item.favorite = next;
		await setFavorite(item.id, next).catch(() => (item.favorite = !next));
	}

	$effect(() => {
		if (!container) return;
		let map: Leaflet.Map | undefined;
		let cancelled = false;

		(async () => {
			try {
				const [L, config, data, token] = await Promise.all([
					import('leaflet'),
					getMapConfig(),
					listLocations(),
					fileToken()
				]);
				if (cancelled || !container) return;
				count = data.items.length;
				map = L.map(container, {
					worldCopyJump: true,
					minZoom: 2,
					maxZoom: config.tiles?.maxZoom ?? 12,
					zoomControl: true,
					attributionControl: true
				});
				map.attributionControl.setPrefix(false);

				// Drawn once the map has a view (labels need screen positions).
				let drawCities = () => {};
				if (config.tiles) {
					L.tileLayer(config.tiles.url, {
						attribution: config.tiles.attribution,
						maxZoom: config.tiles.maxZoom
					}).addTo(map);
				} else {
					const world = await (await fetch('/basemap/world.json')).json();
					if (cancelled) return;
					L.geoJSON(world.countries, {
						style: {
							color: css('--color-border-strong'),
							weight: 0.8,
							fillColor: css('--color-surface'),
							fillOpacity: 1
						},
						interactive: false
					}).addTo(map);
					const labels = L.layerGroup().addTo(map);
					// Most populous first; a label is skipped when it would overlap one already placed.
					drawCities = () => {
						labels.clearLayers();
						const z = map!.getZoom();
						const placed: [number, number, number, number][] = [];
						for (const [name, lat, lon, capital] of world.cities as [
							string,
							number,
							number,
							number
						][]) {
							if (z < 3 || (z < 5 && !capital)) continue;
							const p = map!.latLngToContainerPoint([lat, lon]);
							const w = name.length * 6.5 + 8;
							const box: [number, number, number, number] = [
								p.x - w / 2,
								p.y - 9,
								p.x + w / 2,
								p.y + 9
							];
							if (
								placed.some((b) => box[0] < b[2] && box[2] > b[0] && box[1] < b[3] && box[3] > b[1])
							)
								continue;
							placed.push(box);
							L.marker([lat, lon], {
								interactive: false,
								keyboard: false,
								icon: L.divIcon({ className: 'city', html: `<span>${escapeHtml(name)}</span>` })
							}).addTo(labels);
						}
					};
					map.on('zoomend moveend', () => drawCities());
					map.attributionControl.addAttribution('Natural Earth');
				}

				const markers = L.layerGroup().addTo(map);
				const points = data.items;
				const thumb = (it: Location) =>
					it.thumb
						? pb.files.getURL({ id: it.id, collectionId: data.collectionId }, it.thumb, { token })
						: '';
				const draw = () => {
					markers.clearLayers();
					const z = map!.getZoom();
					const groups = cluster(
						points.map((it) => {
							const p = map!.project([it.lat, it.lon], z);
							return { x: p.x, y: p.y, item: it };
						}),
						CELL
					);
					for (const g of groups) {
						const first = g.items[0]!;
						const latlng = map!.unproject([g.x, g.y], z);
						const label =
							g.items.length > 1 ? m.map_cluster({ count: g.items.length }) : m.map_photo();
						const icon = L.divIcon({
							className: 'photo-pin',
							iconSize: [56, 56],
							html: `<img src="${thumb(first)}" alt="" />${
								g.items.length > 1 ? `<span class="count">${g.items.length}</span>` : ''
							}`
						});
						L.marker(latlng, { icon, title: label, alt: label, keyboard: true, riseOnHover: true })
							.on('click', () => {
								const atMax = z >= map!.getMaxZoom() - 1;
								if (g.items.length > 1 && !atMax) {
									const bounds = L.latLngBounds(g.items.map((it) => [it.lat, it.lon]));
									if (bounds.getNorthEast().equals(bounds.getSouthWest())) {
										openItems(g.items.map((it) => it.id));
									} else {
										map!.fitBounds(bounds.pad(0.3), { maxZoom: map!.getMaxZoom() });
									}
								} else {
									openItems(g.items.map((it) => it.id));
								}
							})
							.addTo(markers);
					}
				};
				map.on('zoomend moveend', draw);

				const focus = page.url.searchParams.get('focus');
				const focused = points.find((it) => it.id === focus);
				if (focused) map.setView([focused.lat, focused.lon], Math.min(14, map.getMaxZoom()));
				else if (points.length)
					map.fitBounds(L.latLngBounds(points.map((it) => [it.lat, it.lon])).pad(0.2), {
						maxZoom: 10
					});
				else map.setView([30, 0], 2);
				drawCities();
				draw();
			} catch {
				failed = true;
			}
		})();

		return () => {
			cancelled = true;
			map?.remove();
		};
	});

	function escapeHtml(s: string) {
		return s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
	}
</script>

<svelte:head>
	<title>{m.map_title()}</title>
</svelte:head>

<div class="head">
	<span class="back-row">
		<a class="back" href={resolve('/(app)/photos')}
			><ArrowLeft size={16} aria-hidden="true" />{m.photos_title()}</a
		>
	</span>
	<h1>{m.map_title()}</h1>
	{#if count !== null}
		<p class="muted"><MapPin size={14} aria-hidden="true" />{m.map_count({ count })}</p>
	{/if}
</div>

{#if failed}
	<Alert>{m.error_load()}</Alert>
{:else}
	<div class="map" bind:this={container} role="region" aria-label={m.map_title()}></div>
	{#if count === 0}<p class="muted empty">{m.map_empty()}</p>{/if}
{/if}

<PhotoViewer items={viewerItems} bind:index={viewerIndex} ontogglefavorite={toggleFavorite} />

<style>
	.head {
		display: flex;
		flex-wrap: wrap;
		align-items: baseline;
		gap: var(--space-1) var(--space-4);
		margin-bottom: var(--space-3);
	}
	.back {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		min-height: 2.25rem;
		margin-inline-start: calc(-1 * var(--space-2));
		padding: 0 var(--space-2);
		border-radius: var(--radius-sm);
		color: var(--color-text-muted);
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		text-decoration: none;
		transition:
			background var(--duration-fast) var(--ease-standard),
			color var(--duration-fast) var(--ease-standard);
	}
	.back:hover {
		color: var(--color-text);
		background: color-mix(in srgb, var(--color-text) 6%, transparent);
	}
	.back-row {
		flex-basis: 100%;
	}
	.muted {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
		margin: 0;
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.empty {
		margin-top: var(--space-3);
	}
	.map {
		height: calc(100dvh - 13rem);
		min-height: 22rem;
		overflow: hidden;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-xl);
		background: var(--color-accent-subtle);
		box-shadow: var(--shadow-sm);
		font: inherit;
	}
	.map :global(.leaflet-container) {
		font: inherit;
	}
	.map :global(.photo-pin) {
		width: 56px;
		height: 56px;
		margin: -28px 0 0 -28px !important;
		border: 3px solid var(--color-surface);
		border-radius: var(--radius-md);
		background: var(--color-surface-sunken);
		box-shadow: var(--shadow-md);
		overflow: visible;
	}
	.map :global(.photo-pin img) {
		display: block;
		width: 100%;
		height: 100%;
		border-radius: calc(var(--radius-md) - 3px);
		object-fit: cover;
	}
	.map :global(.photo-pin:focus-visible) {
		outline: 3px solid var(--color-focus);
		outline-offset: 2px;
	}
	.map :global(.photo-pin .count) {
		position: absolute;
		top: -10px;
		right: -10px;
		min-width: 1.5rem;
		padding: 0 var(--space-1);
		border-radius: var(--radius-full);
		background: var(--color-accent);
		color: var(--color-accent-contrast);
		font-size: var(--text-xs);
		font-weight: var(--weight-semibold);
		line-height: 1.5rem;
		text-align: center;
	}
	.map :global(.city) {
		width: auto !important;
		height: auto !important;
		white-space: nowrap;
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		pointer-events: none;
	}
	.map :global(.city span) {
		position: relative;
		left: -50%;
		text-shadow:
			0 0 2px var(--color-surface),
			0 0 2px var(--color-surface);
	}
	.map :global(.leaflet-control-attribution) {
		font-size: var(--text-xs);
	}
	.map :global(.leaflet-control-attribution),
	.map :global(.leaflet-bar a) {
		background: var(--color-surface-raised);
		color: var(--color-text);
	}
	.map :global(.leaflet-control-attribution a) {
		color: var(--color-accent);
	}
</style>
