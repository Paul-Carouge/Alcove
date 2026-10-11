<script lang="ts">
	import { RotateCcw, Trash2 } from '@lucide/svelte';
	import { ClientResponseError } from 'pocketbase';
	import { deleteForever, listTrash, restoreNode } from '#lib/drive/api.js';
	import FileIcon from '#lib/drive/FileIcon.svelte';
	import { formatDate, formatSize } from '#lib/drive/format.js';
	import { onNodeChange } from '#lib/drive/live.js';
	import type { DriveNode } from '#lib/drive/types.js';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import ActionsMenu from '#lib/ui/ActionsMenu.svelte';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';

	const locale = getLocale();
	let items = $state<DriveNode[]>([]);
	let view = $state<'loading' | 'ready' | 'error'>('loading');
	let error = $state<string | null>(null);
	let confirming = $state<DriveNode | null>(null);
	let confirmOpen = $state(false);
	let busy = $state(false);

	$effect(() => {
		listTrash()
			.then((list) => {
				items = list;
				view = 'ready';
			})
			.catch(() => (view = 'error'));
		return onNodeChange(({ action, record }) => {
			const others = items.filter((i) => i.id !== record.id);
			items = action !== 'delete' && record.trashed_at ? [record, ...others] : others;
		});
	});

	$effect(() => {
		if (!confirmOpen) confirming = null;
	});

	async function restore(node: DriveNode) {
		error = null;
		try {
			await restoreNode(node);
		} catch (err) {
			error =
				err instanceof ClientResponseError && err.status === 400
					? m.error_restore_conflict({ name: node.name })
					: m.error_unexpected();
		}
	}

	function askDelete(node: DriveNode) {
		confirming = node;
		confirmOpen = true;
	}

	async function confirmDelete() {
		if (!confirming) return;
		busy = true;
		try {
			await deleteForever(confirming.id);
			confirmOpen = false;
		} catch {
			error = m.error_unexpected();
			confirmOpen = false;
		} finally {
			busy = false;
		}
	}
</script>

<svelte:head>
	<title>{m.trash_title()}</title>
</svelte:head>

<h1>{m.trash_title()}</h1>
<p class="note">{m.trash_note()}</p>

{#if error}<div class="err"><Alert>{error}</Alert></div>{/if}

{#if view === 'loading'}
	<p class="muted" aria-busy="true">{m.loading()}</p>
{:else if view === 'error'}
	<Alert>{m.error_load()}</Alert>
{:else if items.length === 0}
	<section class="empty" aria-labelledby="empty-title">
		<span class="art" aria-hidden="true"><Trash2 size={24} /></span>
		<h2 id="empty-title">{m.trash_empty_title()}</h2>
		<p>{m.trash_empty_body()}</p>
	</section>
{:else}
	<table class="list">
		<thead>
			<tr>
				<th scope="col">{m.col_name()}</th>
				<th scope="col" class="num">{m.col_size()}</th>
				<th scope="col" class="date">{m.col_trashed()}</th>
				<th scope="col" class="act"
					><span class="visually-hidden">{m.actions_for({ name: '' })}</span></th
				>
			</tr>
		</thead>
		<tbody>
			{#each items as node (node.id)}
				<tr>
					<td>
						<div class="name-cell">
							<FileIcon kind={node.kind} mime={node.mime} />
							<span class="name">{node.name}</span>
						</div>
					</td>
					<td class="num muted">{node.kind === 'folder' ? '—' : formatSize(node.size, locale)}</td>
					<td class="date muted">{formatDate(node.trashed_at, locale)}</td>
					<td class="act">
						<ActionsMenu
							label={m.actions_for({ name: node.name })}
							actions={[
								{ label: m.action_restore(), icon: RotateCcw, onselect: () => restore(node) },
								{
									label: m.action_delete_forever(),
									icon: Trash2,
									danger: true,
									onselect: () => askDelete(node)
								}
							]}
						/>
					</td>
				</tr>
			{/each}
		</tbody>
	</table>
{/if}

<Dialog bind:open={confirmOpen} title={m.delete_forever_title()}>
	<p class="confirm">{m.delete_forever_body({ name: confirming?.name ?? '' })}</p>
	<div class="actions">
		<Button variant="ghost" onclick={() => (confirmOpen = false)}>{m.cancel_button()}</Button>
		<Button variant="danger" loading={busy} onclick={confirmDelete}
			>{m.action_delete_forever()}</Button
		>
	</div>
</Dialog>

<style>
	h1 {
		font-size: var(--text-2xl);
		letter-spacing: -0.02em;
		margin-top: var(--space-2);
	}
	.note {
		margin: var(--space-2) 0 var(--space-5);
		color: var(--color-text-muted);
	}
	.err {
		margin-bottom: var(--space-4);
	}
	.muted {
		color: var(--color-text-muted);
	}
	.list {
		width: 100%;
		border-collapse: separate;
		border-spacing: 0;
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
	}
	th {
		text-align: left;
		font-size: var(--text-xs);
		font-weight: var(--weight-medium);
		text-transform: uppercase;
		letter-spacing: 0.04em;
		color: var(--color-text-muted);
		padding: var(--space-3) var(--space-4);
		border-bottom: 1px solid var(--color-border);
	}
	td {
		padding: var(--space-2) var(--space-4);
		border-bottom: 1px solid var(--color-border);
		font-size: var(--text-sm);
	}
	tbody tr:last-child td {
		border-bottom: 0;
	}
	.num,
	.date {
		width: 9rem;
		white-space: nowrap;
		font-variant-numeric: tabular-nums;
	}
	.num {
		text-align: right;
	}
	.act {
		width: 3.5rem;
		padding: 0 var(--space-2);
		text-align: right;
	}
	.name-cell {
		display: flex;
		align-items: center;
		gap: var(--space-3);
	}
	.name {
		font-size: var(--text-md);
		overflow-wrap: anywhere;
	}
	@media (max-width: 600px) {
		.date {
			display: none;
		}
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
	.art {
		display: grid;
		place-items: center;
		width: 3.5rem;
		height: 3.5rem;
		margin-bottom: var(--space-2);
		border-radius: var(--radius-full);
		background: var(--color-surface-sunken);
		color: var(--color-text-muted);
	}
	.empty h2 {
		font-size: var(--text-lg);
	}
	.empty p {
		margin: 0;
		max-width: 28rem;
		color: var(--color-text-muted);
	}
	.confirm {
		margin: 0;
		color: var(--color-text-muted);
	}
	.actions {
		display: flex;
		justify-content: flex-end;
		gap: var(--space-2);
	}
</style>
