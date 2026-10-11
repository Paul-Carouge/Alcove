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
			{@render children()}
		</main>
		<p class="mobile-credit"><Credit /></p>
	</div>
</div>

<style>
	.split {
		display: grid;
		grid-template-columns: minmax(22rem, 34rem) 1fr;
		min-height: 100dvh;
	}
	.brand-panel {
		position: relative;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		justify-content: space-between;
		gap: var(--space-6);
		padding: var(--space-6);
		background:
			radial-gradient(120% 80% at 0% 0%, var(--color-accent-subtle), transparent 60%),
			radial-gradient(90% 70% at 100% 100%, var(--color-accent-subtle), transparent 55%),
			var(--color-surface);
		border-right: 1px solid var(--color-border);
	}
	.brand-panel::after {
		content: '';
		position: absolute;
		right: -6rem;
		bottom: -6rem;
		width: 22rem;
		height: 22rem;
		border: 1.5px solid var(--color-border);
		border-radius: 50% 50% 0 0;
		opacity: 0.8;
	}
	.pitch {
		position: relative;
		max-width: 26rem;
	}
	.headline {
		margin: 0 0 var(--space-3);
		font-size: var(--text-3xl);
		font-weight: var(--weight-semibold);
		line-height: var(--leading-tight);
		letter-spacing: -0.02em;
	}
	.body {
		margin: 0 0 var(--space-5);
		color: var(--color-text-muted);
		font-size: var(--text-lg);
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
	}
	.ic {
		display: grid;
		place-items: center;
		width: 2rem;
		height: 2rem;
		border-radius: var(--radius-md);
		background: var(--color-surface-raised);
		border: 1px solid var(--color-border);
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
			padding-top: var(--space-6);
		}
	}
</style>
