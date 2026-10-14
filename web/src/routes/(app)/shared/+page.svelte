<script lang="ts">
	import { resolve } from '$app/paths';
	import { BookImage, Link as LinkIcon, Lock, Trash2 } from '@lucide/svelte';
	import FileIcon from '#lib/drive/FileIcon.svelte';
	import { formatDate, formatDateTime } from '#lib/drive/format.js';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import { myShares, revokeShare, type ShareRecord } from '#lib/shares/api.js';
	import Alert from '#lib/ui/Alert.svelte';

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
	<section class="empty" aria-labelledby="empty-title">
		<span class="art" aria-hidden="true"><LinkIcon size={24} /></span>
		<h2 id="empty-title">{m.shared_empty_title()}</h2>
		<p>{m.shared_empty_body()}</p>
	</section>
{:else}
	<table class="list">
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
		color: var(--color-accent);
	}
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
	.small {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
		font-size: var(--text-xs);
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
	tr.expired .ids > :first-child {
		color: var(--color-text-muted);
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
		color: var(--color-text);
		text-decoration: none;
	}
	.date {
		width: 10rem;
		white-space: nowrap;
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
	}
	.icon-btn:hover {
		background: var(--color-surface-sunken);
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
