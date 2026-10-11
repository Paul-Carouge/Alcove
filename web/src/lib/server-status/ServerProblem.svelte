<script lang="ts">
	import { m } from '#lib/paraglide/messages.js';
	import Button from '#lib/ui/Button.svelte';
	import type { ServerStatus } from './status.js';

	let {
		status,
		onretry
	}: { status: Exclude<ServerStatus, { kind: 'connected' }>; onretry: () => void } = $props();
</script>

<section class="card" aria-labelledby="problem-title">
	<h1 id="problem-title">{m.server_status_title()}</h1>
	<p role="alert">
		{#if status.kind === 'error'}
			{status.reason === 'unreachable' ? m.error_unreachable() : m.error_invalid_response()}
		{:else if status.reason === 'client-too-old'}
			{m.error_client_too_old({ min: status.health.api.min, max: status.health.api.max })}
		{:else}
			{m.error_server_too_old({ min: status.health.api.min, max: status.health.api.max })}
		{/if}
	</p>
	{#if status.kind === 'error'}
		<Button variant="secondary" onclick={onretry}>{m.retry()}</Button>
	{/if}
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
		justify-items: start;
	}
	h1 {
		font-size: var(--text-xl);
	}
	p {
		margin: 0;
		color: var(--color-danger);
	}
</style>
