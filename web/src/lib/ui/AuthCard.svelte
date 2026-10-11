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
		display: grid;
		gap: var(--space-5);
	}
	h1 {
		font-size: var(--text-2xl);
		letter-spacing: -0.02em;
	}
	.card :global(form) {
		display: grid;
		gap: var(--space-4);
	}
	.card :global(p) {
		margin: 0;
	}
</style>
