<script lang="ts">
	import type { Snippet } from 'svelte';

	let { title, children }: { title: string; children: Snippet } = $props();
</script>

<section class="card" aria-labelledby="auth-title">
	<h1 id="auth-title">{title}</h1>
	{@render children()}
</section>

<style>
	.card {
		width: min(100%, 24rem);
		padding: var(--space-6);
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		box-shadow: var(--shadow-md);
		display: grid;
		gap: var(--space-4);
	}
	h1 {
		font-size: var(--text-xl);
	}
	.card :global(form) {
		display: grid;
		gap: var(--space-4);
	}
	.card :global(p) {
		margin: 0;
	}
</style>
