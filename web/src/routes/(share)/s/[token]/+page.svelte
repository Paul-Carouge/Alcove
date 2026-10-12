<script lang="ts">
	/* eslint-disable svelte/no-navigation-without-resolve -- links here are API download URLs or same-page query changes */
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { ChevronRight, Download } from '@lucide/svelte';
	import FileIcon from '#lib/drive/FileIcon.svelte';
	import { previewKind } from '#lib/drive/files.js';
	import { formatDate, formatSize } from '#lib/drive/format.js';
	import { compareNodes } from '#lib/drive/names.js';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import type { Media } from '#lib/photos/api.js';
	import PhotoGrid from '#lib/photos/PhotoGrid.svelte';
	import PhotoViewer from '#lib/photos/PhotoViewer.svelte';
	import {
		getPublicShare,
		publicFileUrl,
		publicMediaUrl,
		ShareError,
		unlockShare,
		type PublicMedia,
		type PublicNode,
		type PublicShare
	} from '#lib/shares/api.js';
	import Alert from '#lib/ui/Alert.svelte';
	import AuthCard from '#lib/ui/AuthCard.svelte';
	import Button from '#lib/ui/Button.svelte';
	import TextField from '#lib/ui/TextField.svelte';

	const locale = getLocale();
	const token = $derived(page.params.token ?? '');
	const folder = $derived(page.url.searchParams.get('folder') ?? undefined);
	const accessKey = $derived(`alcove-share-access:${token}`);

	let share = $state<PublicShare | null>(null);
	let view = $state<'loading' | 'ready' | 'locked' | 'not-found' | 'expired' | 'error'>('loading');
	let access = $state<string | undefined>(undefined);
	let password = $state('');
	let unlockError = $state<string | null>(null);
	let busy = $state(false);

	// The unlock token is kept for this tab only.
	function readAccess() {
		try {
			return sessionStorage.getItem(accessKey) ?? undefined;
		} catch {
			return undefined;
		}
	}

	async function load() {
		try {
			share = await getPublicShare(token, access, folder);
			view = 'ready';
		} catch (err) {
			const status = err instanceof ShareError ? err.status : 0;
			view =
				status === 401
					? 'locked'
					: status === 404
						? 'not-found'
						: status === 410
							? 'expired'
							: 'error';
		}
	}

	$effect(() => {
		access ??= readAccess();
		void folder;
		load();
	});

	async function unlock(event: SubmitEvent) {
		event.preventDefault();
		if (!password) return;
		busy = true;
		unlockError = null;
		try {
			const res = await unlockShare(token, password);
			access = res.access;
			try {
				sessionStorage.setItem(accessKey, res.access);
			} catch {
				// Storage unavailable: access lasts until the page is closed.
			}
			await load();
		} catch (err) {
			const status = err instanceof ShareError ? err.status : 0;
			unlockError =
				status === 401
					? m.public_wrong_password()
					: status === 429
						? m.error_too_many_attempts()
						: m.error_unexpected();
		} finally {
			busy = false;
		}
	}

	const children = $derived(
		[...(share?.children ?? [])].sort((a, b) => compareNodes(a, b, locale))
	);
	const fileUrl = (n: PublicNode, inline = false) => publicFileUrl(token, n.id, access, inline);

	// Album links: items in the shape the photo grid and viewer use.
	let viewerIndex = $state(-1);
	const photos = $derived(
		(share?.media ?? []).map(
			(p: PublicMedia) =>
				({
					...p,
					status: p.ready ? 'ready' : 'pending',
					thumb: p.ready ? 'thumb' : '',
					preview: p.ready ? 'preview' : '',
					favorite: false,
					expand: { node: { name: p.name, size: 0, mime: '' } }
				}) as unknown as Media
		)
	);
	const mediaUrl = (it: Media, variant: 'thumb' | 'preview' | 'video') =>
		it.status === 'ready' || variant === 'video'
			? publicMediaUrl(token, it.id, variant, access)
			: null;
	const openFolder = (id: string) => goto(`?folder=${encodeURIComponent(id)}`);
</script>

<svelte:head>
	<title>{share?.album?.name ?? share?.item?.name ?? m.public_shared_with_you()}</title>
	<meta name="robots" content="noindex, nofollow" />
	<meta name="referrer" content="no-referrer" />
</svelte:head>

{#if view === 'loading'}
	<p class="muted" aria-busy="true">{m.loading()}</p>
{:else if view === 'not-found'}
	<Alert tone="info">{m.public_not_found()}</Alert>
{:else if view === 'expired'}
	<Alert tone="info">{m.public_expired()}</Alert>
{:else if view === 'error'}
	<Alert>{m.error_unexpected()}</Alert>
{:else if view === 'locked'}
	<div class="center">
		<AuthCard title={m.public_locked_title()}>
			<p>{m.public_locked_body()}</p>
			<form onsubmit={unlock} novalidate>
				<TextField
					label={m.share_password_label()}
					type="password"
					autocomplete="off"
					bind:value={password}
					error={unlockError}
				/>
				<Button type="submit" loading={busy}>{m.public_unlock()}</Button>
			</form>
		</AuthCard>
	</div>
{:else if share}
	<p class="eyebrow">{m.public_shared_with_you()}</p>
	{#if share.album}
		<section class="album-view" aria-labelledby="album-title">
			<h1 id="album-title">{share.album.name}</h1>
			<p class="muted">
				{m.album_count({ count: photos.length })}
				{#if share.album.owner}· {m.album_shared_by({ name: share.album.owner })}{/if}
				{#if share.expiresAt}· {m.public_expires({
						date: formatDate(share.expiresAt, locale)
					})}{/if}
			</p>
			{#if photos.length}
				<PhotoGrid
					items={photos}
					token=""
					grouped={false}
					thumbOf={(it) => mediaUrl(it, 'thumb')}
					onopen={(it) => (viewerIndex = photos.indexOf(it))}
				/>
			{:else}
				<p class="muted">{m.album_empty_viewer()}</p>
			{/if}
		</section>
		<PhotoViewer
			items={photos}
			bind:index={viewerIndex}
			downloadable={false}
			previewOf={(it) => mediaUrl(it, 'preview')}
			videoOf={(it) => mediaUrl(it, 'video')}
		/>
	{:else if !share.item}
		<Alert>{m.error_unexpected()}</Alert>
	{:else if share.item.kind === 'file'}
		<section class="file-card" aria-labelledby="item-title">
			{#if previewKind(share.item) === 'image'}
				<img class="hero" src={fileUrl(share.item, true)} alt={share.item.name} />
			{:else}
				<span class="big-icon"><FileIcon kind="file" mime={share.item.mime} size={40} /></span>
			{/if}
			<div class="card-body">
				<h1 id="item-title">{share.item.name}</h1>
				<p class="muted">
					{formatSize(share.item.size, locale)}
					{#if share.expiresAt}· {m.public_expires({
							date: formatDate(share.expiresAt, locale)
						})}{/if}
				</p>
				<a class="download" href={fileUrl(share.item)} download>
					<Download size={18} aria-hidden="true" />
					{m.public_download()}
				</a>
			</div>
		</section>
	{:else}
		<h1>{share.item.name}</h1>
		{#if share.expiresAt}<p class="muted">
				{m.public_expires({ date: formatDate(share.expiresAt, locale) })}
			</p>{/if}
		{#if (share.path?.length ?? 0) > 1}
			<nav aria-label={m.breadcrumb_label()} class="crumbs">
				{#each share.path ?? [] as node, i (node.id)}
					{#if i > 0}<ChevronRight size={14} aria-hidden="true" />{/if}
					<button
						class="crumb"
						aria-current={i === (share.path?.length ?? 0) - 1 ? 'location' : undefined}
						onclick={() => openFolder(node.id)}>{node.name}</button
					>
				{/each}
			</nav>
		{/if}
		<ul class="items">
			{#each children as node (node.id)}
				<li>
					<FileIcon kind={node.kind} mime={node.mime} />
					{#if node.kind === 'folder'}
						<button class="name as-link" onclick={() => openFolder(node.id)}>{node.name}</button>
						<span class="muted size">—</span>
					{:else}
						<span class="name">{node.name}</span>
						<span class="muted size">{formatSize(node.size, locale)}</span>
						<a
							class="icon-btn"
							href={fileUrl(node)}
							download
							aria-label={`${m.public_download()} ${node.name}`}
							title={m.public_download()}><Download size={18} aria-hidden="true" /></a
						>
					{/if}
				</li>
			{:else}
				<li class="muted">{m.folder_empty_title()}</li>
			{/each}
		</ul>
	{/if}
{/if}

<style>
	:global(main:has(.album-view)) {
		max-width: 80rem;
	}
	.album-view h1 {
		margin-bottom: var(--space-1);
	}
	.album-view > .muted {
		margin: 0 0 var(--space-5);
	}
	.center {
		display: grid;
		place-items: center;
		padding-top: var(--space-6);
	}
	form {
		display: grid;
		gap: var(--space-4);
	}
	.muted {
		color: var(--color-text-muted);
		margin: 0;
	}
	.eyebrow {
		margin: 0 0 var(--space-3);
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		color: var(--color-accent);
	}
	h1 {
		font-size: var(--text-2xl);
		letter-spacing: -0.02em;
		overflow-wrap: anywhere;
	}
	.file-card {
		display: grid;
		overflow: hidden;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
		box-shadow: var(--shadow-md);
	}
	.hero {
		width: 100%;
		max-height: 60vh;
		object-fit: contain;
		background: var(--color-surface-sunken);
	}
	.big-icon {
		display: grid;
		place-items: center;
		padding: var(--space-7) 0;
		background: var(--color-surface-sunken);
	}
	.card-body {
		display: grid;
		gap: var(--space-2);
		justify-items: start;
		padding: var(--space-5);
	}
	.download {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		margin-top: var(--space-3);
		min-height: 2.75rem;
		padding: 0 var(--space-4);
		border-radius: var(--radius-md);
		background: var(--color-accent);
		color: var(--color-accent-contrast);
		font-weight: var(--weight-medium);
		text-decoration: none;
	}
	.download:hover {
		background: var(--color-accent-hover);
	}
	.crumbs {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-1);
		margin: var(--space-4) 0 0;
		color: var(--color-text-muted);
	}
	.crumb {
		border: 0;
		background: none;
		font: inherit;
		font-size: var(--text-sm);
		color: var(--color-text-muted);
		cursor: pointer;
		min-height: 2rem;
		padding: 0 var(--space-1);
		border-radius: var(--radius-sm);
	}
	.crumb[aria-current='location'] {
		color: var(--color-text);
		font-weight: var(--weight-medium);
	}
	.items {
		list-style: none;
		margin: var(--space-4) 0 0;
		padding: 0;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
	}
	.items li {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-2) var(--space-4);
		border-bottom: 1px solid var(--color-border);
		min-height: 3.25rem;
	}
	.items li:last-child {
		border-bottom: 0;
	}
	.name {
		flex: 1;
		min-width: 0;
		overflow-wrap: anywhere;
	}
	.as-link {
		border: 0;
		background: none;
		padding: 0;
		font: inherit;
		color: var(--color-text);
		text-align: left;
		cursor: pointer;
	}
	.as-link:hover {
		text-decoration: underline;
	}
	.size {
		font-size: var(--text-sm);
		white-space: nowrap;
	}
	.icon-btn {
		display: grid;
		place-items: center;
		width: 2.75rem;
		height: 2.75rem;
		border-radius: var(--radius-md);
		color: var(--color-text);
	}
	.icon-btn:hover {
		background: var(--color-surface-sunken);
	}
</style>
