<script lang="ts">
	import { m } from '#lib/paraglide/messages.js';
	import { serverStatus } from '#lib/server-status/store.svelte.js';
	import LanguageSelect from '#lib/ui/LanguageSelect.svelte';
	import type { LayoutProps } from './$types';

	let { children }: LayoutProps = $props();

	const health = $derived(
		serverStatus.current?.kind === 'connected' ? serverStatus.current.health : null
	);
</script>

<header class="top">
	<LanguageSelect />
</header>

<main id="main" tabindex="-1">
	{#if health}
		<p class="brand"><span class="name">{health.name}</span> · {m.app_tagline()}</p>
	{/if}
	{@render children()}
</main>

{#if health}
	<footer>{m.server_info({ name: health.name, version: health.version })}</footer>
{/if}

<style>
	.top {
		display: flex;
		justify-content: flex-end;
		padding: var(--space-4) var(--space-5);
	}
	main {
		display: grid;
		place-items: center;
		align-content: center;
		gap: var(--space-5);
		padding: var(--space-5);
		min-height: calc(100dvh - 9rem);
	}
	main:focus {
		outline: none;
	}
	.brand {
		margin: 0;
		color: var(--color-text-muted);
	}
	.name {
		color: var(--color-text);
		font-weight: var(--weight-semibold);
	}
	footer {
		text-align: center;
		padding: var(--space-4);
		font-size: var(--text-xs);
		color: var(--color-text-muted);
	}
</style>
