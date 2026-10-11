<script lang="ts">
	import { PRODUCT_NAME } from '#lib/brand.js';
	import { m } from '#lib/paraglide/messages.js';
	import { loadServerStatus, type ServerStatus } from '#lib/server-status/status.js';

	let status = $state<ServerStatus | null>(null);

	async function check() {
		status = null;
		status = await loadServerStatus(window.location.origin);
	}

	$effect(() => {
		check();
	});

	const name = $derived(status && 'health' in status ? status.health.name : PRODUCT_NAME);
</script>

<svelte:head>
	<title>{name}</title>
</svelte:head>

<section class="card" aria-labelledby="title">
	<h1 id="title">{name}</h1>

	<div aria-live="polite" aria-busy={status === null}>
		{#if status === null}
			<p class="muted">{m.checking_server()}</p>
		{:else if status.kind === 'error'}
			<p class="error" role="alert">
				{status.reason === 'unreachable' ? m.error_unreachable() : m.error_invalid_response()}
			</p>
			<button onclick={check}>{m.retry()}</button>
		{:else}
			{@const h = status.health}
			{#if status.kind === 'incompatible'}
				<p class="error" role="alert">
					{status.reason === 'client-too-old'
						? m.error_client_too_old({ min: h.api.min, max: h.api.max })
						: m.error_server_too_old({ min: h.api.min, max: h.api.max })}
				</p>
			{:else}
				<p class="ok"><span class="dot" aria-hidden="true"></span>{m.server_connected()}</p>
			{/if}
			<dl>
				<dt>{m.server_version()}</dt>
				<dd>{h.version}</dd>
				<dt>{m.api_versions()}</dt>
				<dd>{h.api.min}–{h.api.max}</dd>
				<dt>{m.modules()}</dt>
				<dd>{h.modules.join(', ')}</dd>
			</dl>
			{#if h.setupRequired}
				<p class="notice">{m.setup_required()}</p>
			{/if}
		{/if}
	</div>
</section>

<style>
	.card {
		width: min(100%, 26rem);
		padding: var(--space-6);
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		box-shadow: var(--shadow-md);
		display: grid;
		gap: var(--space-4);
	}
	h1 {
		font-size: var(--text-2xl);
	}
	p {
		margin: 0;
	}
	.muted {
		color: var(--color-text-muted);
	}
	.ok {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		color: var(--color-success);
		font-weight: var(--weight-medium);
	}
	.dot {
		width: 0.5rem;
		height: 0.5rem;
		border-radius: var(--radius-full);
		background: currentColor;
	}
	.error {
		color: var(--color-danger);
	}
	.notice {
		padding: var(--space-3);
		background: var(--color-accent-subtle);
		border-radius: var(--radius-md);
		font-size: var(--text-sm);
	}
	dl {
		display: grid;
		grid-template-columns: auto 1fr;
		gap: var(--space-2) var(--space-4);
		margin: var(--space-4) 0 0;
		font-size: var(--text-sm);
	}
	dt {
		color: var(--color-text-muted);
	}
	dd {
		margin: 0;
		font-variant-numeric: tabular-nums;
	}
	button {
		justify-self: start;
		margin-top: var(--space-3);
		font: inherit;
		font-weight: var(--weight-medium);
		min-height: 2.75rem;
		padding: var(--space-2) var(--space-4);
		color: var(--color-accent-contrast);
		background: var(--color-accent);
		border: 0;
		border-radius: var(--radius-md);
		cursor: pointer;
		transition: background var(--duration-fast) var(--ease-standard);
	}
	button:hover {
		background: var(--color-accent-hover);
	}
</style>
