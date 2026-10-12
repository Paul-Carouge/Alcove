<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page as routePage } from '$app/state';
	import { SvelteSet } from 'svelte/reactivity';
	import {
		ArrowLeft,
		CircleCheck,
		ImagePlus,
		Link as LinkIcon,
		LogOut,
		Pencil,
		Share2,
		Star,
		Trash2,
		X
	} from '@lucide/svelte';
	import { onAlbumChange, onAlbumItemChange } from '#lib/drive/live.js';
	import { m } from '#lib/paraglide/messages.js';
	import { pb } from '#lib/pb.js';
	import { fileToken, setFavorite, type Media } from '#lib/photos/api.js';
	import {
		canRemove,
		deleteAlbum,
		getPeople,
		leaveAlbum,
		listAlbumItems,
		removeItem,
		renameAlbum,
		setCover,
		toMedia,
		type AlbumMedia,
		type Participant,
		type Person
	} from '#lib/photos/albums.js';
	import AlbumNameDialog from '#lib/photos/AlbumNameDialog.svelte';
	import PhotoGrid from '#lib/photos/PhotoGrid.svelte';
	import PhotoViewer from '#lib/photos/PhotoViewer.svelte';
	import ShareAlbumDialog from '#lib/photos/ShareAlbumDialog.svelte';
	import ShareDialog from '#lib/shares/ShareDialog.svelte';
	import type { ShareTarget } from '#lib/shares/api.js';
	import ActionsMenu, { type MenuAction } from '#lib/ui/ActionsMenu.svelte';
	import Alert from '#lib/ui/Alert.svelte';
	import Avatar from '#lib/ui/Avatar.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';

	const id = $derived(routePage.params.id ?? '');
	const me = pb.authStore.record?.id ?? '';

	let name = $state('');
	let cover = $state('');
	let owner = $state<Person | null>(null);
	let people = $state<Participant[]>([]);
	let items = $state<AlbumMedia[]>([]);
	let total = $state(0);
	let gone = $state(false);
	let failed = $state(false);
	let loaded = $state(false);
	let token = $state('');
	let viewerIndex = $state(-1);
	let selected = $state<SvelteSet<string> | null>(null);
	let renaming = $state(false);
	let sharing = $state(false);
	let confirmDelete = $state(false);
	let linkTarget = $state<ShareTarget | null>(null);
	let status = $state('');

	const role = $derived(
		owner?.id === me ? 'owner' : (people.find((p) => p.id === me)?.role ?? 'viewer')
	);
	const canAdd = $derived(role === 'owner' || role === 'contributor');
	const removable = $derived(items.filter((it) => canRemove(role, it)));

	async function load() {
		try {
			const [album, ppl] = await Promise.all([pb.collection('albums').getOne(id), getPeople(id)]);
			name = album.name;
			cover = album.cover;
			owner = ppl.owner;
			people = ppl.people;
			const all: AlbumMedia[] = [];
			for (let page = 1; ; page++) {
				const res = await listAlbumItems(id, page, 500);
				all.push(...res.items.map(toMedia));
				total = res.totalItems;
				if (all.length >= res.totalItems || res.items.length === 0) break;
			}
			items = all;
			failed = false;
		} catch (err) {
			if ((err as { status?: number }).status === 404 || String(err).includes('404')) gone = true;
			else failed = true;
		} finally {
			loaded = true;
		}
	}

	$effect(() => {
		void id;
		fileToken().then((t) => (token = t));
		load();
		let timer: ReturnType<typeof setTimeout> | undefined;
		const reload = () => {
			clearTimeout(timer);
			timer = setTimeout(load, 250);
		};
		const refresh = setInterval(() => fileToken().then((t) => (token = t)), 60_000);
		const stopA = onAlbumChange(({ record, action }) => {
			if (record.id !== id) return;
			if (action === 'delete') gone = true;
			else reload();
		});
		const stopI = onAlbumItemChange(({ record }) => {
			if (record.album === id) reload();
		});
		return () => {
			clearTimeout(timer);
			clearInterval(refresh);
			stopA();
			stopI();
		};
	});

	function addPhotos() {
		// eslint-disable-next-line svelte/no-navigation-without-resolve -- resolved path plus a query
		goto(`${resolve('/(app)/photos')}?addTo=${encodeURIComponent(id)}`);
	}

	async function toggleFavorite(item: Media) {
		const next = !item.favorite;
		item.favorite = next;
		try {
			await setFavorite(item.id, next);
		} catch {
			item.favorite = !next;
		}
	}

	async function remove(ids: string[]) {
		const targets = items.filter((it) => ids.includes(it.id) && canRemove(role, it));
		await Promise.allSettled(targets.map((it) => removeItem(it.itemId)));
		items = items.filter((it) => !targets.includes(it));
		total = items.length;
		status = m.album_removed({ count: targets.length });
	}

	async function makeCover(item: Media) {
		await setCover(id, item.id);
		cover = item.id;
		status = m.album_cover_set();
	}

	function toggleSelect(item: Media) {
		if (!selected || !canRemove(role, item as AlbumMedia)) return;
		if (selected.has(item.id)) selected.delete(item.id);
		else selected.add(item.id);
	}

	async function removeSelection() {
		if (!selected?.size) return;
		await remove([...selected]);
		selected = null;
	}

	const menu = $derived.by((): MenuAction[] =>
		role === 'owner'
			? [
					{
						label: m.album_public_link(),
						icon: LinkIcon,
						onselect: () => (linkTarget = { id, name, album: true })
					},
					{ label: m.action_rename(), icon: Pencil, onselect: () => (renaming = true) },
					{
						label: m.album_delete(),
						icon: Trash2,
						danger: true,
						onselect: () => (confirmDelete = true)
					}
				]
			: [
					{
						label: m.album_leave(),
						icon: LogOut,
						danger: true,
						onselect: async () => {
							await leaveAlbum(id);
							goto(resolve('/(app)/albums'));
						}
					}
				]
	);

	function viewerActions(it: Media): MenuAction[] {
		const out: MenuAction[] = [];
		if (role === 'owner' && it.id !== cover)
			out.push({ label: m.album_set_cover(), icon: Star, onselect: () => makeCover(it) });
		if (canRemove(role, it as AlbumMedia))
			out.push({
				label: m.album_remove_item(),
				icon: X,
				danger: true,
				onselect: () => {
					viewerIndex = -1;
					remove([it.id]);
				}
			});
		return out;
	}

	const sharedLine = $derived(
		role === 'owner'
			? people.length
				? m.album_shared_with({ count: people.length })
				: ''
			: m.album_shared_by({ name: owner?.name || owner?.email || m.album_someone() })
	);
</script>

<svelte:head>
	<title>{name || m.albums_title()}</title>
</svelte:head>

<a class="back" href={resolve('/(app)/albums')}
	><ArrowLeft size={16} aria-hidden="true" />{m.albums_title()}</a
>

{#if gone}
	<section class="empty">
		<h1>{m.album_gone_title()}</h1>
		<p>{m.album_gone_body()}</p>
	</section>
{:else if failed}
	<Alert>{m.error_load()}</Alert>
{:else if loaded}
	<div class="head">
		<div class="title">
			<h1>{name}</h1>
			<p class="meta">
				<span>{m.album_count({ count: total })}</span>
				{#if sharedLine}
					<span class="people">
						<span class="avatars" aria-hidden="true">
							{#each [owner, ...people].filter(Boolean).slice(0, 4) as p (p!.id)}
								<Avatar name={p!.name} email={p!.email} size={28} />
							{/each}
						</span>
						{sharedLine}
					</span>
				{/if}
				{#if role !== 'owner'}<span
						>{role === 'contributor' ? m.album_you_contribute() : m.album_you_view()}</span
					>{/if}
			</p>
		</div>
		<div class="tools">
			{#if canAdd}
				<Button variant="secondary" onclick={addPhotos}>
					<ImagePlus size={16} aria-hidden="true" />{m.album_add_photos()}
				</Button>
			{/if}
			{#if role === 'owner'}
				<Button variant="secondary" onclick={() => (sharing = true)}>
					<Share2 size={16} aria-hidden="true" />{m.album_share()}
				</Button>
			{/if}
			{#if removable.length && !selected}
				<Button variant="ghost" onclick={() => (selected = new SvelteSet())}>
					<CircleCheck size={16} aria-hidden="true" />{m.photos_select()}
				</Button>
			{/if}
			<ActionsMenu label={m.album_actions({ name })} actions={menu} />
		</div>
	</div>

	{#if selected}
		<div class="selection-bar" role="region" aria-label={m.photos_selection()}>
			<span class="count">{m.photos_selected({ count: selected.size })}</span>
			<div class="bar-actions">
				<Button variant="ghost" onclick={() => (selected = null)}>
					<X size={16} aria-hidden="true" />{m.cancel_button()}
				</Button>
				<Button variant="danger" disabled={!selected.size} onclick={removeSelection}>
					{m.album_remove_selected()}
				</Button>
			</div>
		</div>
	{/if}
	<p class="status" role="status">{status}</p>

	{#if items.length === 0}
		<section class="empty">
			<p>{canAdd ? m.album_empty_owner() : m.album_empty_viewer()}</p>
		</section>
	{:else}
		<PhotoGrid
			{items}
			{token}
			grouped={false}
			{selected}
			canFavorite={(it) => (it as AlbumMedia).addedBy === me}
			onopen={(it) => (viewerIndex = items.indexOf(it as AlbumMedia))}
			ontogglefavorite={toggleFavorite}
			ontoggleselect={toggleSelect}
		/>
	{/if}
{/if}

<PhotoViewer
	{items}
	bind:index={viewerIndex}
	ontogglefavorite={toggleFavorite}
	canFavorite={(it) => (it as AlbumMedia).addedBy === me}
	actions={viewerActions}
/>
<AlbumNameDialog
	bind:open={renaming}
	title={m.action_rename()}
	submitLabel={m.save_button()}
	initial={name}
	onsubmit={async (n) => {
		await renameAlbum(id, n);
		name = n;
	}}
/>
<ShareAlbumDialog bind:open={sharing} albumId={id} onsaved={load} />
<ShareDialog bind:target={linkTarget} />
<Dialog bind:open={confirmDelete} title={m.album_delete_title({ name })}>
	<p class="confirm">{m.album_delete_body()}</p>
	<div class="actions">
		<Button variant="ghost" onclick={() => (confirmDelete = false)}>{m.cancel_button()}</Button>
		<Button
			variant="danger"
			onclick={async () => {
				await deleteAlbum(id);
				goto(resolve('/(app)/albums'));
			}}>{m.album_delete()}</Button
		>
	</div>
</Dialog>

<style>
	.back {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
		min-height: 2.75rem;
		color: var(--color-text-muted);
		font-size: var(--text-sm);
		text-decoration: none;
	}
	.back:hover {
		color: var(--color-text);
	}
	.head {
		display: flex;
		align-items: flex-end;
		justify-content: space-between;
		flex-wrap: wrap;
		gap: var(--space-4);
		margin-bottom: var(--space-2);
	}
	.title {
		min-width: 0;
	}
	h1 {
		font-size: var(--text-2xl);
		letter-spacing: -0.02em;
		overflow-wrap: anywhere;
	}
	.meta {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-1) var(--space-4);
		margin: var(--space-1) 0 0;
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.people {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
	}
	.avatars {
		display: inline-flex;
	}
	.avatars :global(.avatar + .avatar) {
		margin-left: calc(-1 * var(--space-1));
	}
	.avatars :global(.avatar) {
		box-shadow: 0 0 0 2px var(--color-bg);
	}
	.tools {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-2);
	}
	.status {
		min-height: var(--space-5);
		margin: 0 0 var(--space-2);
		color: var(--color-success);
		font-size: var(--text-sm);
	}
	.empty {
		padding: var(--space-8) var(--space-5);
		border: 1.5px dashed var(--color-border-strong);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
		color: var(--color-text-muted);
		text-align: center;
	}
	.empty h1 {
		color: var(--color-text);
		font-size: var(--text-lg);
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
	.confirm {
		margin: 0 0 var(--space-5);
		color: var(--color-text-muted);
	}
	.actions {
		display: flex;
		justify-content: flex-end;
		gap: var(--space-2);
	}
</style>
