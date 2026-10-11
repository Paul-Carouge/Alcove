<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { m } from '#lib/paraglide/messages.js';

	const title = $derived(page.status === 404 ? m.error_not_found() : m.error_generic());
</script>

<svelte:head>
	<title>{title}</title>
</svelte:head>

<section class="card" aria-labelledby="error-title">
	<p class="code" aria-hidden="true">{page.status}</p>
	<h1 id="error-title">{title}</h1>
	<a href={resolve('/(app)')}>{m.back_home()}</a>
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
		gap: var(--space-3);
		text-align: center;
	}
	.code {
		margin: 0;
		font-size: var(--text-3xl);
		font-weight: var(--weight-semibold);
		color: var(--color-text-muted);
		font-variant-numeric: tabular-nums;
	}
	h1 {
		font-size: var(--text-xl);
	}
	a {
		font-weight: var(--weight-medium);
	}
</style>
