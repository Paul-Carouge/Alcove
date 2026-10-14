<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { BookImage, Plus, Users } from '@lucide/svelte';
	import { onAlbumChange, onAlbumItemChange } from '#lib/drive/live.js';
	import { m } from '#lib/paraglide/messages.js';
	import { pb } from '#lib/pb.js';
	import { fileToken } from '#lib/photos/api.js';
	import { createAlbum, listAlbums, type AlbumSummary } from '#lib/photos/albums.js';
	import AlbumNameDialog from '#lib/photos/AlbumNameDialog.svelte';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import EmptyState from '#lib/ui/EmptyState.svelte';

	let albums = $state<AlbumSummary[] | null>(null);
	let failed = $state(false);
	let token = $state('');
	let creating = $state(false);

	async function load() {
		try {
			albums = await listAlbums();
			failed = false;
		} catch {
			failed = true;
		}
	}

	$effect(() => {
		fileToken().then((t) => (token = t));
		load();
		let timer: ReturnType<typeof setTimeout> | undefined;
		// Counts and covers are computed by the server: refetch, debounced.
		const reload = () => {
			clearTimeout(timer);
			timer = setTimeout(load, 300);
		};
		const stopA = onAlbumChange(reload);
		const stopI = onAlbumItemChange(reload);
		return () => {
			clearTimeout(timer);
			stopA();
			stopI();
		};
	});

	const cover = (a: AlbumSummary) =>
		a.cover && token
			? pb.files.getURL(
					{ id: a.cover.id, collectionId: a.cover.collectionId },
					a.cover.preview || a.cover.thumb,
					{
						token
					}
				)
			: null;

	async function create(name: string) {
		const album = await createAlbum(name);
		goto(resolve('/(app)/albums/[id]', { id: album.id }));
	}

	const sharing = (a: AlbumSummary) =>
		a.role === 'owner'
			? a.shared
				? m.album_shared()
				: ''
			: m.album_shared_by({ name: a.owner.name || m.album_someone() });
</script>

<svelte:head>
	<title>{m.albums_title()}</title>
</svelte:head>

<div class="head">
	<h1>{m.albums_title()}</h1>
	<Button onclick={() => (creating = true)}
		><Plus size={16} aria-hidden="true" />{m.album_new()}</Button
	>
</div>

{#if failed}
	<Alert>{m.error_load()}</Alert>
{:else if albums === null}
	<p class="muted">{m.loading()}</p>
{:else if albums.length === 0}
	<EmptyState icon={BookImage} title={m.albums_empty_title()}>
		{m.albums_empty_body()}
		{#snippet action()}
			<Button onclick={() => (creating = true)}
				><Plus size={16} aria-hidden="true" />{m.album_new()}</Button
			>
		{/snippet}
	</EmptyState>
{:else}
	<ul class="grid">
		{#each albums as a (a.id)}
			<li>
				<a class="card" href={resolve('/(app)/albums/[id]', { id: a.id })}>
					<span class="cover">
						{#if cover(a)}
							<img src={cover(a)} alt="" loading="lazy" />
						{:else}
							<BookImage size={32} aria-hidden="true" />
						{/if}
					</span>
					<span class="name">{a.name}</span>
					<span class="meta">
						{m.album_count({ count: a.count })}
						{#if sharing(a)}<span class="shared"
								><Users size={14} aria-hidden="true" />{sharing(a)}</span
							>{/if}
					</span>
				</a>
			</li>
		{/each}
	</ul>
{/if}

<AlbumNameDialog
	bind:open={creating}
	title={m.album_new()}
	submitLabel={m.create_button()}
	onsubmit={create}
/>

<style>
	.head {
		display: flex;
		align-items: flex-end;
		justify-content: space-between;
		gap: var(--space-4);
		min-height: 3.5rem;
		margin: 0 0 var(--space-6);
	}
	.grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(min(13rem, 40vw), 1fr));
		gap: var(--space-6) var(--space-5);
		margin: 0;
		padding: var(--space-4) 0 0;
		list-style: none;
	}
	.card {
		position: relative;
		isolation: isolate;
		display: grid;
		gap: var(--space-1);
		color: var(--color-text);
		text-decoration: none;
	}
	/* An album reads as a small stack of prints: two sheets peek above the cover. */
	.card::before,
	.card::after {
		content: '';
		position: absolute;
		height: var(--space-7);
		border-radius: var(--radius-lg);
		pointer-events: none;
	}
	.card::before {
		z-index: -1;
		top: calc(-1 * var(--space-2));
		inset-inline: var(--space-3);
		background: color-mix(in srgb, var(--color-border-strong) 50%, var(--color-surface));
	}
	.card::after {
		z-index: -2;
		top: calc(-1 * var(--space-4));
		inset-inline: var(--space-5);
		background: var(--color-border);
	}
	.cover {
		display: grid;
		place-items: center;
		aspect-ratio: 4 / 5;
		overflow: hidden;
		margin-bottom: var(--space-3);
		border-radius: var(--radius-lg);
		background: var(--color-accent-subtle);
		color: var(--color-accent);
		box-shadow: var(--shadow-md);
		transition:
			box-shadow var(--duration-base) var(--ease-standard),
			transform var(--duration-base) var(--ease-standard);
	}
	.card:hover .cover {
		box-shadow: var(--shadow-lg);
		transform: translateY(calc(-1 * var(--space-1)));
	}
	@media (prefers-reduced-motion: reduce) {
		.cover,
		.cover img {
			transition: none;
		}
		.card:hover .cover {
			transform: none;
		}
	}
	.cover img {
		width: 100%;
		height: 100%;
		object-fit: cover;
		transition: transform var(--duration-slow) var(--ease-standard);
	}
	.card:hover .cover img {
		transform: scale(1.03);
	}
	.card:focus-visible {
		outline: none;
	}
	.card:focus-visible .cover {
		outline: 2px solid var(--color-focus);
		outline-offset: 3px;
	}
	.name {
		font-family: var(--font-display);
		font-size: var(--text-lg);
		font-weight: var(--weight-medium);
		line-height: var(--leading-tight);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.meta {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-1) var(--space-3);
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.shared {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
		color: var(--color-accent);
	}
	.muted {
		color: var(--color-text-muted);
	}
	@media (max-width: 600px) {
		.grid {
			grid-template-columns: repeat(2, minmax(0, 1fr));
			gap: var(--space-5) var(--space-3);
		}
		.name {
			font-size: var(--text-md);
		}
	}
</style>
