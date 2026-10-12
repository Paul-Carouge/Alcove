<script lang="ts">
	import { Check, ChevronDown, ChevronUp, RotateCw, X } from '@lucide/svelte';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import FileIcon from './FileIcon.svelte';
	import { formatSize } from './format.js';
	import { uploads, type UploadItem } from './uploads.svelte.js';

	let collapsed = $state(false);

	const items = $derived(uploads.items);
	const done = $derived(items.filter((i) => i.status === 'done').length);
	const finished = $derived(items.some((i) => i.status !== 'queued' && i.status !== 'uploading'));

	const statusText = (i: UploadItem) =>
		({
			queued: m.upload_status_queued(),
			uploading: `${formatSize(i.sent, getLocale())} / ${formatSize(i.size, getLocale())}`,
			done: m.upload_status_done(),
			error: m.upload_status_error(),
			quota: m.upload_status_quota(),
			canceled: m.upload_status_canceled()
		})[i.status];
</script>

{#if items.length > 0}
	<section class="panel" aria-labelledby="uploads-title">
		<header>
			<h2 id="uploads-title">{m.uploads_title()}</h2>
			<span class="summary" aria-live="polite"
				>{m.uploads_summary({ done, total: items.length })}</span
			>
			<button
				class="icon-btn"
				aria-label={collapsed ? m.uploads_expand() : m.uploads_collapse()}
				aria-expanded={!collapsed}
				onclick={() => (collapsed = !collapsed)}
			>
				{#if collapsed}<ChevronUp size={18} aria-hidden="true" />{:else}<ChevronDown
						size={18}
						aria-hidden="true"
					/>{/if}
			</button>
		</header>

		{#if !collapsed}
			<ul>
				{#each items as item (item.id)}
					<li>
						<FileIcon kind="file" size={18} />
						<div class="info">
							<span class="name" title={item.name}>{item.name}</span>
							<span class="status" class:error={item.status === 'error' || item.status === 'quota'}
								>{statusText(item)}</span
							>
							{#if item.status === 'uploading' || item.status === 'queued'}
								<progress max={item.size || 1} value={item.sent} aria-label={item.name}></progress>
							{/if}
						</div>
						{#if item.status === 'done'}
							<Check size={18} class="ok" aria-hidden="true" />
						{:else if item.status === 'error' || item.status === 'quota' || item.status === 'canceled'}
							<button
								class="icon-btn"
								aria-label={m.upload_retry({ name: item.name })}
								onclick={() => uploads.retry(item.id)}
							>
								<RotateCw size={16} aria-hidden="true" />
							</button>
						{:else}
							<button
								class="icon-btn"
								aria-label={m.upload_cancel({ name: item.name })}
								onclick={() => uploads.cancel(item.id)}
							>
								<X size={16} aria-hidden="true" />
							</button>
						{/if}
					</li>
				{/each}
			</ul>
			{#if finished}
				<footer>
					<button class="link" onclick={() => uploads.clearFinished()}>{m.uploads_clear()}</button>
				</footer>
			{/if}
		{/if}
	</section>
{/if}

<style>
	.panel {
		position: fixed;
		right: var(--space-5);
		bottom: var(--space-5);
		z-index: 15;
		width: min(24rem, calc(100vw - 2 * var(--space-4)));
		background: var(--color-surface-raised);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		box-shadow: var(--shadow-lg);
		overflow: hidden;
		animation: rise var(--duration-base) var(--ease-emphasized);
	}
	@keyframes rise {
		from {
			opacity: 0;
			transform: translateY(12px);
		}
	}
	header {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2) var(--space-2) var(--space-2) var(--space-4);
		border-bottom: 1px solid var(--color-border);
	}
	h2 {
		font-size: var(--text-md);
	}
	.summary {
		margin-left: auto;
		font-size: var(--text-sm);
		color: var(--color-text-muted);
	}
	ul {
		list-style: none;
		margin: 0;
		padding: var(--space-1) 0;
		max-height: 18rem;
		overflow-y: auto;
	}
	li {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-2) var(--space-2) var(--space-2) var(--space-4);
	}
	.info {
		flex: 1;
		min-width: 0;
		display: grid;
		gap: 2px;
	}
	.name {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
	}
	.status {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		font-variant-numeric: tabular-nums;
	}
	.status.error {
		color: var(--color-danger);
	}
	progress {
		width: 100%;
		height: 4px;
		appearance: none;
		border: 0;
		border-radius: var(--radius-full);
		background: var(--color-surface-sunken);
		overflow: hidden;
	}
	progress::-webkit-progress-bar {
		background: var(--color-surface-sunken);
	}
	progress::-webkit-progress-value {
		background: var(--color-accent);
		transition: width var(--duration-base) var(--ease-standard);
	}
	progress::-moz-progress-bar {
		background: var(--color-accent);
	}
	:global(.ok) {
		color: var(--color-success);
		margin-right: var(--space-3);
	}
	.icon-btn {
		display: grid;
		place-items: center;
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
	footer {
		display: flex;
		justify-content: flex-end;
		padding: var(--space-1) var(--space-3) var(--space-2);
		border-top: 1px solid var(--color-border);
	}
	.link {
		border: 0;
		background: none;
		font: inherit;
		font-size: var(--text-sm);
		color: var(--color-accent);
		cursor: pointer;
		min-height: 2.75rem;
		padding: 0 var(--space-2);
	}
</style>
