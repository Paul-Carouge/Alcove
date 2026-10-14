<script lang="ts">
	import { Lock, RefreshCw, Server } from '@lucide/svelte';
	import { m } from '#lib/paraglide/messages.js';
	import { serverStatus } from '#lib/server-status/store.svelte.js';
	import LanguageSelect from '#lib/ui/LanguageSelect.svelte';
	import Credit from '#lib/ui/Credit.svelte';
	import Logo from '#lib/ui/Logo.svelte';
	import type { LayoutProps } from './$types';

	let { children }: LayoutProps = $props();

	const health = $derived(
		serverStatus.current?.kind === 'connected' ? serverStatus.current.health : null
	);
	const features = [
		{ icon: Lock, text: m.feature_private },
		{ icon: RefreshCw, text: m.feature_realtime },
		{ icon: Server, text: m.feature_open }
	];
</script>

<div class="split">
	<aside class="brand-panel" aria-label={m.app_tagline()}>
		<Logo name={health?.name} size={36} />
		<span class="arches" aria-hidden="true"></span>
		<div class="pitch">
			<p class="headline">{m.brand_headline()}</p>
			<p class="body">{m.brand_body()}</p>
			<ul>
				{#each features as f (f.text)}
					<li><span class="ic" aria-hidden="true"><f.icon size={16} /></span>{f.text()}</li>
				{/each}
			</ul>
		</div>
		<p class="foot">
			{#if health}{m.server_info({ name: health.name, version: health.version })} ·{/if}
			<Credit />
		</p>
	</aside>

	<div class="form-side">
		<header class="top">
			<span class="mobile-logo"><Logo name={health?.name} /></span>
			<LanguageSelect />
		</header>
		<main id="main" tabindex="-1">
			<div class="sheet">
				{@render children()}
			</div>
		</main>
		<p class="mobile-credit"><Credit /></p>
	</div>
</div>

<style>
	.split {
		display: grid;
		grid-template-columns: minmax(24rem, 36rem) 1fr;
		min-height: 100dvh;
	}
	.brand-panel {
		position: relative;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		justify-content: space-between;
		gap: var(--space-6);
		padding: var(--space-6) var(--space-7);
		background:
			radial-gradient(90% 60% at 100% 100%, var(--color-accent-subtle), transparent 70%),
			var(--color-surface-sunken);
		border-right: 1px solid var(--color-border);
	}
	/* Nested arches echo the logo: a quiet alcove drawn in hairlines. */
	.arches,
	.arches::before,
	.arches::after {
		position: absolute;
		border: 1px solid var(--color-border-strong);
		border-bottom: 0;
		border-radius: var(--radius-full) var(--radius-full) 0 0;
		opacity: 0.45;
		pointer-events: none;
	}
	.arches {
		right: -7rem;
		bottom: 0;
		width: 20rem;
		height: 28rem;
	}
	.arches::before,
	.arches::after {
		content: '';
		left: 50%;
		bottom: 0;
		transform: translateX(-50%);
	}
	.arches::before {
		width: calc(100% - var(--space-7) * 2);
		height: calc(100% - var(--space-7));
	}
	.arches::after {
		width: calc(100% - var(--space-8) * 3);
		height: calc(100% - var(--space-8) * 2);
		background: color-mix(in srgb, var(--color-accent) 8%, transparent);
	}
	.pitch {
		position: relative;
		max-width: 26rem;
	}
	.headline {
		margin: 0 0 var(--space-4);
		font-family: var(--font-display);
		font-optical-sizing: auto;
		font-size: calc(var(--text-3xl) * 1.25);
		font-weight: var(--weight-regular);
		line-height: 1.1;
		letter-spacing: -0.025em;
		text-wrap: balance;
	}
	.body {
		margin: 0 0 var(--space-6);
		color: var(--color-text-muted);
		font-size: var(--text-lg);
		max-width: 34ch;
	}
	ul {
		list-style: none;
		margin: 0;
		padding: 0;
		display: grid;
		gap: var(--space-3);
	}
	li {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		font-size: var(--text-sm);
	}
	.ic {
		display: grid;
		place-items: center;
		width: 2rem;
		height: 2rem;
		border-radius: var(--radius-full);
		background: var(--color-surface);
		box-shadow: var(--shadow-sm);
		color: var(--color-accent);
	}
	.foot {
		position: relative;
		margin: 0;
		font-size: var(--text-xs);
		color: var(--color-text-muted);
	}
	.form-side {
		display: flex;
		flex-direction: column;
	}
	.top {
		display: flex;
		align-items: center;
		justify-content: flex-end;
		padding: var(--space-4) var(--space-5);
	}
	.mobile-logo {
		display: none;
		margin-right: auto;
	}
	.mobile-credit {
		display: none;
		margin: 0;
		padding: var(--space-4);
		text-align: center;
	}
	main {
		flex: 1;
		display: grid;
		place-items: center;
		padding: var(--space-5);
	}
	main:focus {
		outline: none;
	}
	.sheet {
		display: grid;
		justify-items: center;
		width: min(100%, 28rem);
		padding: var(--space-7) var(--space-6);
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-xl);
		box-shadow: var(--shadow-md);
	}
	.sheet :global(a) {
		justify-self: start;
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
	}
	@media (max-width: 900px) {
		.split {
			grid-template-columns: 1fr;
		}
		.brand-panel {
			display: none;
		}
		.mobile-logo {
			display: inline-flex;
		}
		.mobile-credit {
			display: block;
		}
		main {
			align-items: start;
			padding: var(--space-4) var(--space-4) var(--space-5);
		}
	}
	@media (max-width: 600px) {
		.top {
			padding: var(--space-3) var(--space-4);
		}
		.sheet {
			padding: var(--space-6) var(--space-5);
		}
	}
</style>
