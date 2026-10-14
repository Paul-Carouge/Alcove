<script lang="ts">
	import { resolve } from '$app/paths';
	import { BookImage, Link as LinkIcon, Lock, Trash2 } from '@lucide/svelte';
	import FileIcon from '#lib/drive/FileIcon.svelte';
	import { formatDate, formatDateTime } from '#lib/drive/format.js';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import { myShares, revokeShare, type ShareRecord } from '#lib/shares/api.js';
	import Alert from '#lib/ui/Alert.svelte';
	import EmptyState from '#lib/ui/EmptyState.svelte';

	const locale = getLocale();
	let items = $state<ShareRecord[]>([]);
	let view = $state<'loading' | 'ready' | 'error'>('loading');
	let error = $state<string | null>(null);

	$effect(() => {
		myShares()
			.then((list) => {
				items = list;
				view = 'ready';
			})
			.catch(() => (view = 'error'));
	});

	async function revoke(share: ShareRecord) {
		error = null;
		try {
			await revokeShare(share.id);
			items = items.filter((s) => s.id !== share.id);
		} catch {
			error = m.error_unexpected();
		}
	}

	const expired = (s: ShareRecord) =>
		!!s.expires_at && new Date(s.expires_at.replace(' ', 'T')) < new Date();
</script>

<svelte:head>
	<title>{m.shared_title()}</title>
</svelte:head>

<h1>{m.shared_title()}</h1>
<p class="note">{m.shared_note()}</p>

{#if error}<div class="err"><Alert>{error}</Alert></div>{/if}

{#if view === 'loading'}
	<p class="muted" aria-busy="true">{m.loading()}</p>
{:else if view === 'error'}
	<Alert>{m.error_load()}</Alert>
{:else if items.length === 0}
	<EmptyState icon={LinkIcon} title={m.shared_empty_title()}>
		{m.shared_empty_body()}
	</EmptyState>
{:else}
	<table class="list data-table">
		<thead>
			<tr>
				<th scope="col">{m.col_item()}</th>
				<th scope="col" class="date">{m.col_expires()}</th>
				<th scope="col" class="act"><span class="visually-hidden">{m.share_revoke()}</span></th>
			</tr>
		</thead>
		<tbody>
			{#each items as share (share.id)}
				{@const node = share.expand?.node}
				{@const album = share.expand?.album}
				<tr class:expired={expired(share)}>
					<td>
						<div class="name-cell">
							{#if album}<span class="album-icon"><BookImage size={20} aria-hidden="true" /></span
								>{:else if node}<FileIcon kind={node.kind} mime={node.mime} />{/if}
							<div class="ids">
								{#if album}
									<a href={resolve('/(app)/albums/[id]', { id: album.id })}>{album.name}</a>
								{:else if node?.kind === 'folder'}
									<a href={resolve('/(app)/folders/[id]', { id: node.id })}>{node.name}</a>
								{:else}
									<span>{node?.name ?? '—'}</span>
								{/if}
								<span class="muted small">
									{m.share_created({ date: formatDateTime(share.created, locale) })}
									{#if share.has_password}· <Lock size={12} aria-hidden="true" />
										{m.share_protected()}{/if}
								</span>
								<span class="muted small expiry">
									{share.expires_at
										? expired(share)
											? m.public_expired()
											: m.share_expires_on({ date: formatDate(share.expires_at, locale) })
										: m.share_no_expiry()}
								</span>
							</div>
						</div>
					</td>
					<td class="date muted">
						{share.expires_at
							? expired(share)
								? m.public_expired()
								: formatDate(share.expires_at, locale)
							: m.share_no_expiry()}
					</td>
					<td class="act">
						<button
							class="icon-btn"
							aria-label={m.share_revoke_label({ date: formatDateTime(share.created, locale) })}
							title={m.share_revoke()}
							onclick={() => revoke(share)}
						>
							<Trash2 size={16} aria-hidden="true" />
						</button>
					</td>
				</tr>
			{/each}
		</tbody>
	</table>
{/if}

<style>
	.album-icon {
		display: grid;
		place-items: center;
		flex: none;
		width: 2.5rem;
		height: 2.5rem;
		border-radius: var(--radius-md);
		background: var(--color-accent-subtle);
		color: var(--color-accent);
	}
	h1 {
		padding-top: var(--space-3);
	}
	.note {
		max-width: 44rem;
		margin: var(--space-2) 0 var(--space-6);
		color: var(--color-text-muted);
	}
	.err {
		margin-bottom: var(--space-4);
	}
	.muted {
		color: var(--color-text-muted);
	}
	.small {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
		font-size: var(--text-xs);
	}
	tr.expired .ids > :first-child {
		color: var(--color-text-muted);
		text-decoration: line-through;
		text-decoration-color: var(--color-border-strong);
	}
	.name-cell {
		display: flex;
		align-items: center;
		gap: var(--space-3);
	}
	.ids {
		display: grid;
	}
	.ids a,
	.ids > span:first-child {
		font-size: var(--text-md);
		font-weight: var(--weight-medium);
		color: var(--color-text);
		text-decoration: none;
	}
	.ids a:hover {
		text-decoration: underline;
		text-decoration-color: var(--color-border-strong);
	}
	.date {
		width: 10rem;
		white-space: nowrap;
		font-variant-numeric: tabular-nums;
	}
	.act {
		width: 3.5rem;
		text-align: right;
		padding: 0 var(--space-2);
	}
	.icon-btn {
		display: grid;
		place-items: center;
		width: 2.75rem;
		height: 2.75rem;
		border: 0;
		border-radius: var(--radius-md);
		background: transparent;
		color: var(--color-danger);
		cursor: pointer;
		transition: background var(--duration-fast) var(--ease-standard);
	}
	.icon-btn:hover {
		background: color-mix(in srgb, var(--color-danger) 10%, transparent);
	}
	.expiry {
		display: none;
	}
	/* Phones: the expiry column moves under the name. */
	@media (max-width: 600px) {
		.date {
			display: none;
		}
		.expiry {
			display: inline;
		}
	}
</style>
