<script lang="ts">
	import { beforeNavigate, goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { tick, untrack } from 'svelte';
	import {
		ArchiveRestore,
		ArrowLeft,
		CloudAlert,
		CloudCheck,
		NotebookPen,
		Pin,
		Plus,
		Search as SearchIcon,
		Tag as TagIcon,
		Trash2
	} from '@lucide/svelte';
	import { onNoteChange } from '#lib/drive/live.js';
	import { formatDate } from '#lib/drive/format.js';
	import { renderMarkdown } from '#lib/notes/markdown.js';
	import {
		Autosave,
		createNote,
		deleteNote,
		excerpt,
		filterNotes,
		notesCol,
		nowDate,
		sortNotes,
		updateNote,
		type Note
	} from '#lib/notes/notes.svelte.js';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import TagChip from '#lib/tags/TagChip.svelte';
	import TagsDialog from '#lib/tags/TagsDialog.svelte';
	import { tags } from '#lib/tags/tags.svelte.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';
	import EmptyState from '#lib/ui/EmptyState.svelte';

	const locale = getLocale();

	let items = $state<Note[] | null>(null);
	let failed = $state(false);
	let view = $state<'notes' | 'trash'>('notes');
	let query = $state('');
	let tagFilter = $state('');
	let mode = $state<'write' | 'preview'>('write');
	let draftTitle = $state('');
	let draftBody = $state('');
	let saver = $state<Autosave | null>(null);
	// One saver per note with edits not on the server yet, so switching notes never loses them.
	// eslint-disable-next-line svelte/prefer-svelte-reactivity -- not rendered; each saver's state is
	const savers = new Map<string, Autosave>();
	let loadedId = '';
	let creating = $state(false);
	let taggingOpen = $state(false);
	let confirmOpen = $state(false);
	let busy = $state(false);
	let actionError = $state('');
	let titleInput = $state<HTMLInputElement>();

	const selectedId = $derived(page.url.searchParams.get('n') ?? '');
	const selected = $derived(items?.find((n) => n.id === selectedId) ?? null);
	const inView = $derived(
		sortNotes((items ?? []).filter((n) => (view === 'trash') === !!n.trashed_at))
	);
	const shown = $derived(filterNotes(inView, query, tagFilter));
	const preview = $derived(mode === 'preview' || !!selected?.trashed_at);

	const titleOf = (n: Pick<Note, 'title' | 'body'>) =>
		n.title.trim() || excerpt(n.body, 60) || m.notes_untitled();
	const tagsOf = (ids: string[] | undefined) =>
		(ids ?? []).map((id) => tags.byId.get(id)).filter((t) => t !== undefined);

	/** Puts a record in the list; a note with unsaved edits keeps them. */
	function upsert(rec: Note) {
		if (!items) return;
		const pending = savers.get(rec.id);
		const note = pending?.dirty ? { ...rec, ...pending.unsaved } : rec;
		items = items.some((n) => n.id === rec.id)
			? items.map((n) => (n.id === rec.id ? note : n))
			: [note, ...items];
	}

	// shortcut: loads every note with its text; page the list (without bodies) when it gets large.
	async function load() {
		try {
			items = await notesCol().getFullList({ batch: 500, sort: '-updated' });
			failed = false;
		} catch {
			failed = true;
		}
	}

	$effect(() => {
		load();
		tags.load().catch(() => {});
		// Other devices and tabs: apply their changes, except over edits not saved yet.
		return onNoteChange<Note>((e) => {
			if (!items) return;
			if (e.action === 'delete') {
				items = items.filter((n) => n.id !== e.record.id);
				return;
			}
			// A late echo of an older save (ours or not) must not undo newer text.
			const known = items.find((n) => n.id === e.record.id);
			if (known && e.record.updated <= known.updated) return;
			upsert(e.record);
			if (e.record.id === loadedId && !saver?.dirty) {
				draftTitle = e.record.title;
				draftBody = e.record.body;
			}
		});
	});

	// Opening another note: send the edits of the previous one, then load the new one.
	$effect(() => {
		const id = selectedId;
		if (!items || id === loadedId) return;
		const note = items.find((n) => n.id === id);
		if (id && !note) return;
		untrack(() => {
			const prev = saver;
			const prevId = loadedId;
			if (prev) void prev.flush().then(() => forget(prevId, prev));
			loadedId = id;
			saver = note ? (savers.get(id) ?? newSaver(id)) : null;
			const unsaved = saver?.unsaved ?? {};
			draftTitle = unsaved.title ?? note?.title ?? '';
			draftBody = unsaved.body ?? note?.body ?? '';
			actionError = '';
			if (note?.trashed_at) view = 'trash';
		});
	});

	// A deleted tag can no longer filter.
	$effect(() => {
		if (tagFilter && tags.loaded && !tags.byId.has(tagFilter)) tagFilter = '';
	});

	function newSaver(id: string) {
		const s = new Autosave((changes) => updateNote(id, changes).then((rec) => upsert(rec)));
		savers.set(id, s);
		return s;
	}

	/** Drops the saver of a note left behind once everything reached the server. */
	function forget(id: string, s: Autosave) {
		if (s !== saver && !s.dirty && savers.get(id) === s) savers.delete(id);
	}

	const anyDirty = () => [...savers.values()].some((s) => s.dirty);

	beforeNavigate((nav) => {
		// Switching notes stays on this page: the savers carry on.
		if (nav.to?.route.id === nav.from?.route.id) return;
		for (const s of savers.values()) void s.flush();
		const failedSave = [...savers.values()].some((s) => s.state === 'error');
		if (failedSave && nav.type !== 'leave' && !confirm(m.notes_leave_unsaved())) nav.cancel();
	});

	function onBeforeUnload(e: BeforeUnloadEvent) {
		if (!anyDirty()) return;
		for (const s of savers.values()) void s.flush();
		e.preventDefault();
	}

	function select(id: string) {
		const base = resolve('/(app)/notes');
		// eslint-disable-next-line svelte/no-navigation-without-resolve -- resolved path plus a query
		return goto(id ? `${base}?n=${encodeURIComponent(id)}` : base, { reset: false });
	}

	function edit() {
		if (!selected) return;
		saver?.change({ title: draftTitle, body: draftBody });
		// The list follows the typing.
		items = (items ?? []).map((n) =>
			n.id === selected.id ? { ...n, title: draftTitle, body: draftBody } : n
		);
	}

	async function newNote() {
		creating = true;
		try {
			const note = await createNote();
			upsert(note);
			view = 'notes';
			query = '';
			tagFilter = '';
			mode = 'write';
			await select(note.id);
			await tick();
			titleInput?.focus();
		} catch {
			actionError = m.error_unexpected();
		} finally {
			creating = false;
		}
	}

	async function act(change: Promise<Note | unknown>) {
		actionError = '';
		try {
			const rec = await change;
			if (rec && typeof rec === 'object' && 'id' in rec) upsert(rec as Note);
			return true;
		} catch {
			actionError = m.error_unexpected();
			return false;
		}
	}

	const togglePin = (n: Note) => act(updateNote(n.id, { pinned: !n.pinned }));

	async function trash(n: Note) {
		await saver?.flush();
		if (saver?.state === 'error') {
			actionError = m.notes_save_failed();
			return;
		}
		if (await act(updateNote(n.id, { trashed_at: nowDate() }))) select('');
	}

	async function restore(n: Note) {
		if (await act(updateNote(n.id, { trashed_at: '' }))) view = 'notes';
	}

	async function deleteForever() {
		if (!selected) return;
		busy = true;
		const id = selected.id;
		saver?.cancel();
		savers.delete(id);
		if (await act(deleteNote(id))) {
			items = (items ?? []).filter((n) => n.id !== id);
			confirmOpen = false;
			select('');
		}
		busy = false;
	}

	function setView(v: 'notes' | 'trash') {
		view = v;
		if (selected && (v === 'trash') !== !!selected.trashed_at) select('');
	}
</script>

<svelte:head>
	<title>{selected ? titleOf(selected) : m.nav_notes()}</title>
</svelte:head>
<svelte:window onbeforeunload={onBeforeUnload} />

<div class="head" class:open={!!selectedId}>
	<h1>{m.nav_notes()}</h1>
	<Button onclick={newNote} loading={creating}>
		<Plus size={16} aria-hidden="true" />{m.notes_new()}
	</Button>
</div>

{#if failed}
	<Alert>{m.error_load()}</Alert>
{:else if items !== null && items.length === 0}
	<div class="empty">
		<EmptyState icon={NotebookPen} title={m.notes_empty_title()}>
			{m.notes_empty()}
			{#snippet action()}
				<Button onclick={newNote} loading={creating}>
					<Plus size={16} aria-hidden="true" />{m.notes_new()}
				</Button>
			{/snippet}
		</EmptyState>
	</div>
{:else}
	<div class="notes" class:open={!!selectedId}>
		<section class="list-pane" aria-label={m.notes_list_label()}>
			<div class="tools">
				<div class="chips" role="radiogroup" aria-label={m.notes_view()}>
					{#each [['notes', m.nav_notes], ['trash', m.nav_trash]] as const as [value, label] (value)}
						<button
							role="radio"
							aria-checked={view === value}
							class:on={view === value}
							onclick={() => setView(value)}>{label()}</button
						>
					{/each}
				</div>
				<label class="search">
					<SearchIcon size={16} aria-hidden="true" />
					<span class="visually-hidden">{m.notes_search()}</span>
					<input
						type="search"
						bind:value={query}
						placeholder={m.notes_search()}
						autocomplete="off"
					/>
				</label>
				{#if tags.items.length}
					<div class="tag-filter" role="radiogroup" aria-label={m.tags_filter()}>
						<button
							role="radio"
							aria-checked={tagFilter === ''}
							class="tag-all"
							class:on={tagFilter === ''}
							onclick={() => (tagFilter = '')}>{m.tags_any()}</button
						>
						{#each tags.items as t (t.id)}
							<button
								role="radio"
								aria-checked={tagFilter === t.id}
								class="tag-opt"
								class:on={tagFilter === t.id}
								onclick={() => (tagFilter = tagFilter === t.id ? '' : t.id)}
								><TagChip tag={t} /></button
							>
						{/each}
					</div>
				{/if}
			</div>

			{#if items === null}
				<ul class="list" aria-busy="true" aria-label={m.loading()}>
					{#each [0, 1, 2] as i (i)}<li class="skeleton"></li>{/each}
				</ul>
			{:else if shown.length === 0}
				<p class="muted none" role="status">
					{query
						? m.notes_none({ q: query })
						: tagFilter
							? m.notes_none({ q: tags.byId.get(tagFilter)?.name ?? '' })
							: view === 'trash'
								? m.notes_trash_empty()
								: m.notes_empty_title()}
				</p>
				{#if view === 'trash'}<p class="muted small">{m.trash_note()}</p>{/if}
			{:else}
				<p class="muted small" role="status">{m.notes_count({ count: shown.length })}</p>
				<ul class="list">
					{#each shown as n (n.id)}
						<li>
							<button
								class="item"
								aria-current={n.id === selectedId ? 'true' : undefined}
								onclick={() => select(n.id)}
							>
								<span class="item-title">
									{#if n.pinned}<Pin size={14} aria-label={m.notes_pinned()} />{/if}
									<span class="ellipsis">{titleOf(n)}</span>
								</span>
								{#if excerpt(n.body) && n.title.trim()}
									<span class="item-excerpt">{excerpt(n.body)}</span>
								{/if}
								<span class="item-meta">
									{#each tagsOf(n.tags) as t (t.id)}<TagChip tag={t} />{/each}
									<span
										>{n.trashed_at
											? m.notes_trashed_at({ date: formatDate(n.trashed_at, locale) })
											: formatDate(n.updated, locale)}</span
									>
								</span>
							</button>
						</li>
					{/each}
				</ul>
				{#if view === 'trash'}<p class="muted small">{m.trash_note()}</p>{/if}
			{/if}
		</section>

		<section class="editor-pane" aria-label={selected ? titleOf(selected) : m.nav_notes()}>
			{#if selected}
				<div class="toolbar">
					<button class="icon-btn back" aria-label={m.notes_back()} onclick={() => select('')}>
						<ArrowLeft size={20} aria-hidden="true" />
					</button>
					{#if !selected.trashed_at}
						<div class="chips small-chips" role="radiogroup" aria-label={m.notes_mode()}>
							<button
								role="radio"
								aria-checked={mode === 'write'}
								class:on={mode === 'write'}
								onclick={() => (mode = 'write')}>{m.notes_write()}</button
							>
							<button
								role="radio"
								aria-checked={mode === 'preview'}
								class:on={mode === 'preview'}
								onclick={() => (mode = 'preview')}>{m.notes_preview()}</button
							>
						</div>
					{/if}
					<span class="spacer"></span>
					{#if !selected.trashed_at}
						<span class="status" role="status">
							{#if saver?.state === 'error'}
								<button class="retry" onclick={() => saver?.flush()}>
									<CloudAlert size={16} aria-hidden="true" />{m.notes_save_failed()} · {m.retry()}
								</button>
							{:else if saver?.state === 'pending' || saver?.state === 'saving'}
								{m.notes_saving()}
							{:else if saver?.state === 'saved'}
								<CloudCheck size={16} aria-hidden="true" />{m.notes_saved()}
							{:else}
								{m.notes_updated({ date: formatDate(selected.updated, locale) })}
							{/if}
						</span>
						<button
							class="icon-btn"
							aria-label={selected.pinned ? m.notes_unpin() : m.notes_pin()}
							title={selected.pinned ? m.notes_unpin() : m.notes_pin()}
							aria-pressed={selected.pinned}
							onclick={() => togglePin(selected)}
						>
							<Pin size={18} aria-hidden="true" />
						</button>
						<button
							class="icon-btn"
							aria-label={m.tags_edit_for({ name: titleOf(selected) })}
							title={m.tags_edit_for({ name: titleOf(selected) })}
							onclick={() => (taggingOpen = true)}
						>
							<TagIcon size={18} aria-hidden="true" />
						</button>
						<button
							class="icon-btn"
							aria-label={m.action_trash()}
							title={m.action_trash()}
							onclick={() => trash(selected)}
						>
							<Trash2 size={18} aria-hidden="true" />
						</button>
					{/if}
				</div>

				{#if actionError}<Alert>{actionError}</Alert>{/if}

				<div class="sheet">
					{#if selected.trashed_at}
						<div class="trashed">
							<p>{m.notes_in_trash()}</p>
							<div class="trashed-actions">
								<Button variant="secondary" onclick={() => restore(selected)}>
									<ArchiveRestore size={16} aria-hidden="true" />{m.action_restore()}
								</Button>
								<Button variant="danger" onclick={() => (confirmOpen = true)}>
									{m.action_delete_forever()}
								</Button>
							</div>
						</div>
						<h2 class="title-view">{titleOf(selected)}</h2>
					{:else}
						<input
							bind:this={titleInput}
							class="title"
							bind:value={draftTitle}
							oninput={edit}
							onblur={() => saver?.flush()}
							maxlength="200"
							readonly={creating}
							placeholder={m.notes_untitled()}
							aria-label={m.notes_title_label()}
						/>
					{/if}
					{#if tagsOf(selected.tags).length}
						<p class="note-tags">
							{#each tagsOf(selected.tags) as t (t.id)}<TagChip tag={t} size="md" />{/each}
						</p>
					{/if}
					{#if preview}
						{#if draftBody.trim()}
							<!-- renderMarkdown escapes all HTML before formatting. -->
							<!-- eslint-disable-next-line svelte/no-at-html-tags -->
							<div class="rendered">{@html renderMarkdown(draftBody)}</div>
						{:else}
							<p class="muted">{m.notes_preview_empty()}</p>
						{/if}
					{:else}
						<textarea
							class="body"
							bind:value={draftBody}
							oninput={edit}
							onblur={() => saver?.flush()}
							readonly={creating}
							placeholder={m.notes_body_placeholder()}
							aria-label={m.notes_body_label()}></textarea>
					{/if}
				</div>
			{:else if selectedId && items !== null}
				<div class="placeholder">
					<button class="icon-btn back" aria-label={m.notes_back()} onclick={() => select('')}>
						<ArrowLeft size={20} aria-hidden="true" />
					</button>
					<p class="muted">{m.notes_not_found()}</p>
				</div>
			{:else}
				<div class="placeholder">
					<span class="art" aria-hidden="true"><NotebookPen size={24} strokeWidth={1.75} /></span>
					<p class="muted">{m.notes_select()}</p>
				</div>
			{/if}
		</section>
	</div>
{/if}

<TagsDialog
	bind:open={taggingOpen}
	node={selected ? { id: selected.id, name: titleOf(selected), tags: selected.tags } : null}
	save={(ids) => updateNote(selected!.id, { tags: ids }).then(upsert)}
/>

<Dialog bind:open={confirmOpen} title={m.delete_forever_title()}>
	<p class="confirm">{m.notes_delete_forever_body({ name: selected ? titleOf(selected) : '' })}</p>
	<div class="actions">
		<Button variant="ghost" onclick={() => (confirmOpen = false)}>{m.cancel_button()}</Button>
		<Button variant="danger" loading={busy} onclick={deleteForever}
			>{m.action_delete_forever()}</Button
		>
	</div>
</Dialog>

<style>
	.head {
		display: flex;
		align-items: flex-end;
		justify-content: space-between;
		flex-wrap: wrap;
		gap: var(--space-3);
		min-height: 3.5rem;
		margin: 0 0 var(--space-5);
	}
	.empty {
		max-width: 44rem;
	}
	.notes {
		display: grid;
		grid-template-columns: minmax(16rem, 22rem) minmax(0, 1fr);
		gap: var(--space-6);
		align-items: start;
	}
	.list-pane {
		display: grid;
		gap: var(--space-3);
		min-width: 0;
	}
	.tools {
		display: grid;
		gap: var(--space-3);
	}
	.chips {
		display: inline-flex;
		justify-self: start;
		max-width: 100%;
		gap: var(--space-1);
		padding: var(--space-1);
		border-radius: var(--radius-full);
		background: var(--color-surface-sunken);
	}
	.chips button {
		flex-shrink: 0;
		min-height: 2.25rem;
		padding: 0 var(--space-4);
		border: 0;
		border-radius: var(--radius-full);
		background: transparent;
		color: var(--color-text-muted);
		font: inherit;
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		cursor: pointer;
		transition:
			background var(--duration-fast) var(--ease-standard),
			color var(--duration-fast) var(--ease-standard);
	}
	.chips button:hover {
		color: var(--color-text);
	}
	.chips button.on {
		background: var(--color-surface);
		color: var(--color-text);
		box-shadow: var(--shadow-sm);
	}
	.search {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		min-height: 2.75rem;
		padding: 0 var(--space-4);
		border: 1px solid var(--color-border-strong);
		border-radius: var(--radius-full);
		background: var(--color-surface);
		color: var(--color-text-muted);
	}
	.search:focus-within {
		border-color: var(--color-focus);
		box-shadow: 0 0 0 3px var(--color-accent-subtle);
	}
	.search input {
		flex: 1;
		min-width: 0;
		min-height: 2.5rem;
		border: 0;
		background: transparent;
		color: var(--color-text);
		font: inherit;
		font-size: var(--text-sm);
		outline: none;
	}
	.tag-filter {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-1);
	}
	.tag-filter button {
		display: inline-flex;
		align-items: center;
		min-height: 2.75rem;
		padding: 0 var(--space-1);
		border: 1px solid transparent;
		border-radius: var(--radius-full);
		background: none;
		cursor: pointer;
	}
	.tag-filter button:hover {
		border-color: var(--color-border);
	}
	.tag-filter .tag-all {
		padding: 0 var(--space-3);
		color: var(--color-text-muted);
		font: inherit;
		font-size: var(--text-xs);
		font-weight: var(--weight-medium);
	}
	.tag-filter button.on {
		border-color: var(--color-accent);
		background: var(--color-surface);
	}
	.tag-filter .tag-all.on {
		color: var(--color-text);
	}
	.muted {
		margin: 0;
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.small {
		font-size: var(--text-xs);
	}
	.none {
		padding: var(--space-4) 0;
	}
	.list {
		margin: 0;
		padding: 0;
		list-style: none;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
		box-shadow: var(--shadow-sm);
		overflow: hidden;
	}
	.list li + li {
		border-top: 1px solid var(--color-border);
	}
	.skeleton {
		height: 4.5rem;
		background: var(--color-surface-sunken);
		opacity: 0.6;
	}
	.item {
		position: relative;
		display: grid;
		gap: var(--space-1);
		width: 100%;
		min-height: 3.5rem;
		padding: var(--space-3) var(--space-4);
		border: 0;
		background: transparent;
		color: var(--color-text);
		font: inherit;
		text-align: start;
		cursor: pointer;
		transition: background var(--duration-fast) var(--ease-standard);
	}
	.item:hover {
		background: color-mix(in srgb, var(--color-surface-sunken) 60%, transparent);
	}
	.item[aria-current] {
		background: var(--color-accent-subtle);
	}
	.item[aria-current]::before {
		content: '';
		position: absolute;
		inset-block: var(--space-2);
		inset-inline-start: 0;
		width: var(--space-1);
		border-radius: var(--radius-full);
		background: var(--color-accent);
	}
	.item-title {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		min-width: 0;
		font-family: var(--font-display);
		font-size: var(--text-md);
		font-weight: var(--weight-medium);
		line-height: var(--leading-tight);
	}
	.item-title :global(svg) {
		flex: none;
		color: var(--color-accent);
	}
	.ellipsis,
	.item-excerpt {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.item-excerpt {
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.item-meta {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-1);
		color: var(--color-text-muted);
		font-size: var(--text-xs);
	}

	.editor-pane {
		display: grid;
		grid-template-columns: minmax(0, 1fr);
		gap: var(--space-3);
		min-width: 0;
	}
	.toolbar {
		display: flex;
		align-items: center;
		gap: var(--space-1);
		min-height: 2.75rem;
	}
	.small-chips button {
		min-height: 2rem;
		padding: 0 var(--space-3);
	}
	.spacer {
		flex: 1;
	}
	.status {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
		margin-inline-end: var(--space-2);
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		white-space: nowrap;
	}
	.retry {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
		min-height: 2.75rem;
		padding: 0 var(--space-2);
		border: 0;
		border-radius: var(--radius-md);
		background: transparent;
		color: var(--color-danger);
		font: inherit;
		font-weight: var(--weight-medium);
		cursor: pointer;
	}
	.icon-btn {
		display: grid;
		place-items: center;
		flex: none;
		width: 2.75rem;
		height: 2.75rem;
		border: 0;
		border-radius: var(--radius-md);
		background: transparent;
		color: var(--color-text-muted);
		cursor: pointer;
	}
	.icon-btn:hover {
		background: var(--color-surface-sunken);
		color: var(--color-text);
	}
	.icon-btn[aria-pressed='true'] {
		color: var(--color-accent);
	}
	.back {
		display: none;
	}
	.sheet {
		display: grid;
		grid-template-columns: minmax(0, 1fr);
		align-content: start;
		gap: var(--space-3);
		min-height: 60dvh;
		padding: var(--space-6) var(--space-7);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-xl);
		background: var(--color-surface);
		box-shadow: var(--shadow-sm);
	}
	.title,
	.title-view {
		width: 100%;
		margin: 0;
		padding: 0;
		border: 0;
		background: transparent;
		color: var(--color-text);
		font-family: var(--font-display);
		font-size: var(--text-2xl);
		font-weight: var(--weight-medium);
		line-height: var(--leading-tight);
		outline: none;
	}
	.title::placeholder,
	.body::placeholder {
		color: var(--color-text-muted);
	}
	.title:focus-visible,
	.body:focus-visible {
		outline: none;
	}
	.note-tags {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-1);
		margin: 0;
	}
	.body {
		width: 100%;
		min-height: 50dvh;
		padding: 0;
		border: 0;
		background: transparent;
		color: var(--color-text);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		line-height: var(--leading-normal);
		resize: vertical;
		field-sizing: content;
	}
	.rendered {
		max-width: 70ch;
		line-height: var(--leading-normal);
		overflow-wrap: anywhere;
	}
	.rendered :global(:is(h2, h3, h4)) {
		margin: var(--space-5) 0 var(--space-2);
	}
	.rendered :global(h2) {
		font-size: var(--text-xl);
	}
	.rendered :global(h3) {
		font-size: var(--text-lg);
	}
	.rendered :global(h4) {
		font-size: var(--text-md);
	}
	.rendered :global(:first-child) {
		margin-top: 0;
	}
	.rendered :global(:is(p, ul, ol, blockquote, pre)) {
		margin: 0 0 var(--space-3);
	}
	.rendered :global(:is(ul, ol)) {
		padding-inline-start: var(--space-5);
	}
	.rendered :global(li.task) {
		list-style: none;
		margin-inline-start: calc(-1 * var(--space-5));
	}
	.rendered :global(li.task.done) {
		color: var(--color-text-muted);
		text-decoration: line-through;
	}
	.rendered :global(input[type='checkbox']) {
		accent-color: var(--color-accent);
		margin-inline-end: var(--space-1);
	}
	.rendered :global(blockquote) {
		padding-inline-start: var(--space-4);
		border-inline-start: 3px solid var(--color-border-strong);
		color: var(--color-text-muted);
	}
	.rendered :global(code) {
		padding: 0 var(--space-1);
		border-radius: var(--radius-sm);
		background: var(--color-surface-sunken);
		font-family: var(--font-mono);
		font-size: 0.9em;
	}
	.rendered :global(pre) {
		padding: var(--space-3) var(--space-4);
		overflow-x: auto;
		border-radius: var(--radius-md);
		background: var(--color-surface-sunken);
	}
	.rendered :global(pre code) {
		padding: 0;
		background: none;
	}
	.rendered :global(hr) {
		border: 0;
		border-top: 1px solid var(--color-border);
		margin: var(--space-5) 0;
	}
	.trashed {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
		padding: var(--space-3) var(--space-4);
		border-radius: var(--radius-md);
		background: var(--color-surface-sunken);
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.trashed p {
		margin: 0;
	}
	.trashed-actions {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
	}
	.placeholder {
		display: grid;
		justify-items: center;
		align-content: center;
		gap: var(--space-3);
		min-height: 40dvh;
		padding: var(--space-6);
		border: 1px dashed var(--color-border-strong);
		border-radius: var(--radius-xl);
		text-align: center;
	}
	.art {
		display: grid;
		place-items: center;
		width: 3.5rem;
		height: 3.5rem;
		border-radius: var(--radius-full) var(--radius-full) var(--radius-md) var(--radius-md);
		background: var(--color-accent-subtle);
		color: var(--color-accent);
	}
	.confirm {
		margin: 0;
	}

	/* Phones: the save state goes under the tools. */
	@media (max-width: 600px) {
		.toolbar {
			flex-wrap: wrap;
		}
		.status {
			order: 1;
			flex-basis: 100%;
			margin: 0 0 0 var(--space-3);
		}
		.small-chips button {
			padding: 0 var(--space-3);
		}
	}

	/* Phones and small tablets: the list, or the open note. */
	@media (max-width: 900px) {
		.notes {
			grid-template-columns: minmax(0, 1fr);
		}
		.notes.open .list-pane,
		.notes:not(.open) .editor-pane {
			display: none;
		}
		.head.open {
			display: none;
		}
		.back {
			display: grid;
		}
		.toolbar {
			gap: 0;
		}
		.placeholder .back {
			justify-self: start;
		}
		.sheet {
			padding: var(--space-5) var(--space-4);
			border-radius: var(--radius-lg);
		}
		.title,
		.title-view {
			font-size: var(--text-xl);
		}
	}
</style>
