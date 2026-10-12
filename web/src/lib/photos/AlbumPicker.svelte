<script lang="ts">
	import { BookImage, Plus } from '@lucide/svelte';
	import { m } from '#lib/paraglide/messages.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';
	import TextField from '#lib/ui/TextField.svelte';
	import { fileToken } from './api.js';
	import { addToAlbum, canAddTo, createAlbum, listAlbums, type AlbumSummary } from './albums.js';
	import { pb } from '#lib/pb.js';

	let {
		open = $bindable(false),
		mediaIds,
		onadded
	}: {
		open?: boolean;
		mediaIds: string[];
		onadded: (album: { id: string; name: string }, added: number) => void;
	} = $props();

	let albums = $state<AlbumSummary[] | null>(null);
	let token = $state('');
	let newName = $state('');
	let busy = $state<string | null>(null);
	let failed = $state(false);

	$effect(() => {
		if (!open) return;
		albums = null;
		newName = '';
		failed = false;
		fileToken().then((t) => (token = t));
		listAlbums()
			.then((list) => (albums = list.filter(canAddTo)))
			.catch(() => (failed = true));
	});

	async function pick(album: { id: string; name: string }) {
		busy = album.id;
		try {
			const added = await addToAlbum(album.id, mediaIds);
			open = false;
			onadded(album, added);
		} catch {
			failed = true;
		} finally {
			busy = null;
		}
	}

	async function create(event: SubmitEvent) {
		event.preventDefault();
		const name = newName.trim();
		if (!name) return;
		busy = 'new';
		try {
			const album = await createAlbum(name);
			busy = null;
			await pick(album);
		} catch {
			failed = true;
			busy = null;
		}
	}

	const cover = (a: AlbumSummary) =>
		a.cover && token
			? pb.files.getURL({ id: a.cover.id, collectionId: a.cover.collectionId }, a.cover.thumb, {
					token
				})
			: null;
</script>

<Dialog bind:open title={m.album_add_title({ count: mediaIds.length })}>
	{#if failed}<Alert>{m.error_unexpected()}</Alert>{/if}
	{#if albums === null && !failed}
		<p class="muted">{m.loading()}</p>
	{:else if albums?.length}
		<ul class="list">
			{#each albums as a (a.id)}
				<li>
					<button class="album" disabled={busy !== null} onclick={() => pick(a)}>
						<span class="thumb">
							{#if cover(a)}<img src={cover(a)} alt="" />{:else}<BookImage
									size={18}
									aria-hidden="true"
								/>{/if}
						</span>
						<span class="text">
							<span class="name">{a.name}</span>
							<span class="muted">{m.album_count({ count: a.count })}</span>
						</span>
						{#if busy === a.id}<span class="muted">{m.loading()}</span>{/if}
					</button>
				</li>
			{/each}
		</ul>
	{/if}
	<form onsubmit={create} class="new">
		<TextField
			label={m.album_new_label()}
			bind:value={newName}
			maxlength={100}
			autocomplete="off"
		/>
		<Button type="submit" variant="secondary" loading={busy === 'new'} disabled={!newName.trim()}>
			<Plus size={16} aria-hidden="true" />{m.album_create_and_add()}
		</Button>
	</form>
	<div class="actions">
		<Button variant="ghost" onclick={() => (open = false)}>{m.cancel_button()}</Button>
	</div>
</Dialog>

<style>
	.list {
		display: grid;
		gap: var(--space-1);
		max-height: 18rem;
		overflow-y: auto;
		margin: 0 0 var(--space-4);
		padding: 0;
		list-style: none;
	}
	.album {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		width: 100%;
		min-height: 3.5rem;
		padding: var(--space-2);
		border: 0;
		border-radius: var(--radius-md);
		background: transparent;
		color: var(--color-text);
		font: inherit;
		text-align: left;
		cursor: pointer;
	}
	.album:hover,
	.album:focus-visible {
		background: var(--color-surface-sunken);
	}
	.thumb {
		display: grid;
		place-items: center;
		flex: none;
		width: 2.75rem;
		height: 2.75rem;
		overflow: hidden;
		border-radius: var(--radius-sm);
		background: var(--color-accent-subtle);
		color: var(--color-accent);
	}
	.thumb img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}
	.text {
		display: grid;
		flex: 1;
		min-width: 0;
	}
	.name {
		font-weight: var(--weight-medium);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.muted {
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.new {
		display: grid;
		gap: var(--space-2);
		padding-top: var(--space-4);
		border-top: 1px solid var(--color-border);
	}
	.actions {
		display: flex;
		justify-content: flex-end;
		margin-top: var(--space-4);
	}
</style>
