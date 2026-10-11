<script lang="ts">
	import { m } from '#lib/paraglide/messages.js';
</script>

<svelte:head>
	<title>{m.files_title()}</title>
</svelte:head>

<h1>{m.files_title()}</h1>

<section class="empty" aria-labelledby="empty-title">
	<svg
		aria-hidden="true"
		viewBox="0 0 24 24"
		width="40"
		height="40"
		fill="none"
		stroke="currentColor"
		stroke-width="1.5"
		stroke-linecap="round"
		stroke-linejoin="round"
	>
		<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
	</svg>
	<h2 id="empty-title">{m.files_empty_title()}</h2>
	<p>{m.files_empty_body()}</p>
</section>

<style>
	h1 {
		font-size: var(--text-2xl);
		margin-bottom: var(--space-5);
	}
	.empty {
		display: grid;
		justify-items: center;
		gap: var(--space-2);
		padding: var(--space-8) var(--space-5);
		border: 1px dashed var(--color-border-strong);
		border-radius: var(--radius-lg);
		background: var(--color-surface-sunken);
		text-align: center;
		color: var(--color-text-muted);
	}
	h2 {
		font-size: var(--text-lg);
		color: var(--color-text);
	}
	p {
		margin: 0;
	}
</style>
