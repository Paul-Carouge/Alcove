<script lang="ts">
	import { resolve } from '$app/paths';
	import { ArrowLeft, Copy, Sparkles, Trash2 } from '@lucide/svelte';
	import { trashNode } from '#lib/drive/api.js';
	import { formatDate, formatSize } from '#lib/drive/format.js';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import { pb } from '#lib/pb.js';
	import {
		dismissDuplicates,
		fileToken,
		listDuplicates,
		type DuplicateGroup,
		type DuplicateItem
	} from '#lib/photos/api.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';

	const locale = getLocale();
	let groups = $state<DuplicateGroup[] | null>(null);
	let failed = $state(false);
	let token = $state('');
	let status = $state('');
	let busy = $state<string | null>(null);
	let confirmAll = $state(false);
	/** Items marked for the trash, per group (keyed by the group's first item). */
	let marked = $state<Record<string, string[]>>({});

	const keyOf = (g: DuplicateGroup) => g.items[0]!.id;

	async function load() {
		try {
			groups = await listDuplicates();
			marked = Object.fromEntries(
				groups.map((g) => [keyOf(g), g.items.filter((it) => it.id !== g.keep).map((it) => it.id)])
			);
			failed = false;
		} catch {
			failed = true;
		}
	}

	$effect(() => {
		fileToken().then((t) => (token = t));
		load();
	});

	function toggle(g: DuplicateGroup, it: DuplicateItem) {
		const list = marked[keyOf(g)] ?? [];
		marked[keyOf(g)] = list.includes(it.id) ? list.filter((x) => x !== it.id) : [...list, it.id];
	}

	const trashOf = (g: DuplicateGroup) => g.items.filter((it) => marked[keyOf(g)]?.includes(it.id));
	const freed = (list: DuplicateItem[]) => list.reduce((n, it) => n + it.size, 0);
	const totalFreed = $derived(groups ? freed(groups.flatMap(trashOf)) : 0);

	async function trash(list: DuplicateItem[]) {
		await Promise.allSettled(list.map((it) => trashNode(it.node)));
		status = m.duplicates_trashed({ count: list.length, size: formatSize(freed(list), locale) });
	}

	async function clean(g: DuplicateGroup) {
		const list = trashOf(g);
		if (!list.length) return;
		busy = keyOf(g);
		try {
			await trash(list);
			groups = groups!.filter((x) => x !== g);
		} finally {
			busy = null;
		}
	}

	async function dismiss(g: DuplicateGroup) {
		busy = keyOf(g);
		try {
			await dismissDuplicates(g.items.map((it) => it.id));
			groups = groups!.filter((x) => x !== g);
			status = m.duplicates_dismissed();
		} catch {
			status = m.error_unexpected();
		} finally {
			busy = null;
		}
	}

	async function cleanAll() {
		confirmAll = false;
		busy = 'all';
		try {
			await trash(groups!.flatMap(trashOf));
			await load();
		} finally {
			busy = null;
		}
	}

	const thumb = (it: DuplicateItem) =>
		it.thumb && token
			? pb.files.getURL({ id: it.id, collectionId: it.collectionId }, it.thumb, { token })
			: null;
	const ratio = (it: DuplicateItem) => (it.width && it.height ? it.width / it.height : 1);
</script>

<svelte:head>
	<title>{m.duplicates_title()}</title>
</svelte:head>

<a class="back" href={resolve('/(app)/photos')}
	><ArrowLeft size={16} aria-hidden="true" />{m.photos_title()}</a
>
<div class="head">
	<div>
		<h1>{m.duplicates_title()}</h1>
		<p class="intro">{m.duplicates_intro()}</p>
	</div>
	{#if groups?.length}
		<Button loading={busy === 'all'} disabled={!totalFreed} onclick={() => (confirmAll = true)}>
			<Sparkles size={16} aria-hidden="true" />{m.duplicates_clean_all({
				size: formatSize(totalFreed, locale)
			})}
		</Button>
	{/if}
</div>

<p class="status" role="status">{status}</p>

{#if failed}
	<Alert>{m.error_load()}</Alert>
{:else if groups === null}
	<p class="muted">{m.loading()}</p>
{:else if groups.length === 0}
	<section class="empty">
		<span class="art" aria-hidden="true"><Copy size={26} /></span>
		<h2>{m.duplicates_none_title()}</h2>
		<p>{m.duplicates_none_body()}</p>
	</section>
{:else}
	<ul class="groups">
		{#each groups as g (keyOf(g))}
			{@const toTrash = trashOf(g)}
			<li class="group">
				<div class="group-head">
					<h2>
						{g.kind === 'identical' ? m.duplicates_identical() : m.duplicates_similar()}
						<span class="muted">· {m.album_count({ count: g.items.length })}</span>
					</h2>
					<div class="group-actions">
						<Button variant="ghost" disabled={busy !== null} onclick={() => dismiss(g)}>
							{m.duplicates_not_duplicates()}
						</Button>
						<Button
							variant="secondary"
							disabled={!toTrash.length || busy !== null}
							loading={busy === keyOf(g)}
							onclick={() => clean(g)}
						>
							<Trash2 size={16} aria-hidden="true" />{m.duplicates_trash_some({
								count: toTrash.length
							})}
						</Button>
					</div>
				</div>
				<ul class="items">
					{#each g.items as it (it.id)}
						{@const out = toTrash.includes(it)}
						<li>
							<button
								class="tile"
								class:out
								style:aspect-ratio={ratio(it)}
								aria-pressed={out}
								aria-label={out
									? m.duplicates_marked({ name: it.name })
									: m.duplicates_kept({ name: it.name })}
								onclick={() => toggle(g, it)}
							>
								{#if thumb(it)}<img src={thumb(it)} alt="" loading="lazy" />{/if}
								<span class="tag" class:trash={out}
									>{out ? m.duplicates_tag_trash() : m.duplicates_tag_keep()}</span
								>
								{#if it.id === g.keep}<span class="best">{m.duplicates_best()}</span>{/if}
							</button>
							<p class="meta">
								<span class="name">{it.name}</span>
								<span class="muted"
									>{it.width} × {it.height} · {formatSize(it.size, locale)} · {formatDate(
										it.created,
										locale
									)}</span
								>
							</p>
						</li>
					{/each}
				</ul>
			</li>
		{/each}
	</ul>
{/if}

<Dialog bind:open={confirmAll} title={m.duplicates_clean_all_title()}>
	<p class="confirm">
		{m.duplicates_clean_all_body({
			count: groups?.flatMap(trashOf).length ?? 0,
			size: formatSize(totalFreed, locale)
		})}
	</p>
	<div class="actions">
		<Button variant="ghost" onclick={() => (confirmAll = false)}>{m.cancel_button()}</Button>
		<Button onclick={cleanAll}>{m.duplicates_clean_all_confirm()}</Button>
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
	}
	h1 {
		font-size: var(--text-2xl);
		letter-spacing: -0.02em;
	}
	.intro {
		margin: var(--space-1) 0 0;
		max-width: 40rem;
		color: var(--color-text-muted);
	}
	.status {
		min-height: var(--space-5);
		margin: var(--space-2) 0;
		color: var(--color-success);
		font-size: var(--text-sm);
	}
	.groups {
		display: grid;
		gap: var(--space-5);
		margin: 0;
		padding: 0;
		list-style: none;
	}
	.group {
		padding: var(--space-4) var(--space-5) var(--space-5);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
	}
	.group-head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		flex-wrap: wrap;
		gap: var(--space-3);
		margin-bottom: var(--space-3);
	}
	.group-head h2 {
		font-size: var(--text-md);
	}
	.group-actions {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
	}
	.items {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-4);
		margin: 0;
		padding: 0;
		list-style: none;
	}
	.items li {
		width: min(12rem, 42vw);
	}
	.tile {
		position: relative;
		display: block;
		width: 100%;
		max-height: 12rem;
		padding: 0;
		overflow: hidden;
		border: 2px solid transparent;
		border-radius: var(--radius-md);
		background: var(--color-surface-sunken);
		cursor: pointer;
	}
	.tile img {
		display: block;
		width: 100%;
		height: 100%;
		object-fit: cover;
		transition: opacity var(--duration-fast) var(--ease-standard);
	}
	.tile.out img {
		opacity: 0.45;
	}
	.tile:not(.out) {
		border-color: var(--color-accent);
	}
	.tag,
	.best {
		position: absolute;
		padding: 1px var(--space-2);
		border-radius: var(--radius-full);
		font-size: var(--text-xs);
		font-weight: var(--weight-medium);
	}
	.tag {
		bottom: var(--space-2);
		left: var(--space-2);
		background: var(--color-accent);
		color: var(--color-accent-contrast);
	}
	.tag.trash {
		background: var(--color-stage-scrim);
		color: var(--color-on-stage);
	}
	.best {
		top: var(--space-2);
		right: var(--space-2);
		background: var(--color-surface);
		color: var(--color-text);
		box-shadow: var(--shadow-sm);
	}
	.meta {
		display: grid;
		margin: var(--space-2) 0 0;
		font-size: var(--text-sm);
	}
	.name {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.muted {
		color: var(--color-text-muted);
		font-weight: var(--weight-regular);
	}
	.meta .muted {
		font-size: var(--text-xs);
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
	.empty h2 {
		font-size: var(--text-lg);
	}
	.empty p {
		margin: 0;
		color: var(--color-text-muted);
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
