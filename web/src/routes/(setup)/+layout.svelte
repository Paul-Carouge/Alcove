<script lang="ts">
	import Credit from '#lib/ui/Credit.svelte';
	import LanguageSelect from '#lib/ui/LanguageSelect.svelte';
	import Logo from '#lib/ui/Logo.svelte';
	import { serverStatus } from '#lib/server-status/store.svelte.js';
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
		min-height: 4rem;
		padding: var(--space-2) var(--space-5);
	}
	main {
		max-width: 40rem;
		margin: 0 auto;
		padding: var(--space-5) var(--space-5) var(--space-6);
	}
	@media (max-width: 600px) {
		.top {
			padding: var(--space-2) var(--space-4);
		}
		main {
			padding: var(--space-4);
		}
	}
	main:focus {
		outline: none;
	}
	.foot {
		padding: var(--space-5);
		text-align: center;
	}
</style>
