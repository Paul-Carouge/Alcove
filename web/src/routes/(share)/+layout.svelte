<script lang="ts">
	import { serverStatus } from '#lib/server-status/store.svelte.js';
	import LanguageSelect from '#lib/ui/LanguageSelect.svelte';
	import Credit from '#lib/ui/Credit.svelte';
	import Logo from '#lib/ui/Logo.svelte';
	import type { LayoutProps } from './$types';

	let { children }: LayoutProps = $props();
	const health = $derived(
		serverStatus.current?.kind === 'connected' ? serverStatus.current.health : null
	);
</script>

<header class="top">
	<Logo name={health?.name} />
	<LanguageSelect />
</header>
<main id="main" tabindex="-1">
	{@render children()}
</main>
<footer class="foot"><Credit /></footer>

<style>
	.top {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
		position: sticky;
		top: 0;
		z-index: 5;
		min-height: 4rem;
		padding: var(--space-2) var(--space-5);
		border-bottom: 1px solid var(--color-border);
		background: color-mix(in srgb, var(--color-bg) 88%, transparent);
		backdrop-filter: blur(var(--space-3));
	}
	main {
		max-width: 72rem;
		margin: 0 auto;
		padding: var(--space-6) var(--space-5);
	}
	main:focus {
		outline: none;
	}
	.foot {
		padding: var(--space-6) var(--space-5);
		text-align: center;
	}
	@media (max-width: 600px) {
		.top {
			padding: var(--space-2) var(--space-4);
		}
		main {
			padding: var(--space-5) var(--space-4);
		}
	}
</style>
