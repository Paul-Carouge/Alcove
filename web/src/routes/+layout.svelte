<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { onMount } from 'svelte';
	import '@fontsource-variable/inter';
	import '#lib/styles/tokens.css';
	import '#lib/styles/base.css';
	import favicon from '#lib/assets/favicon.svg';
	import { session } from '#lib/auth/session.svelte.js';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import ServerProblem from '#lib/server-status/ServerProblem.svelte';
	import { serverStatus } from '#lib/server-status/store.svelte.js';
	import { theme } from '#lib/theme/theme.svelte.js';
	import type { LayoutProps } from './$types';

	let { children }: LayoutProps = $props();

	// One-time startup. (An $effect would re-run whenever state it reads, like
	// the theme, changes, re-checking the server and remounting the app.)
	onMount(() => {
		document.documentElement.lang = getLocale();
		theme.apply();
		serverStatus.check();
		session.refresh();
	});

	const status = $derived(serverStatus.current);

	// Until an administrator exists, every page leads to the setup wizard.
	$effect(() => {
		if (
			status?.kind === 'connected' &&
			status.health.setupRequired &&
			!page.url.pathname.startsWith('/setup')
		) {
			const token = page.url.searchParams.get('token');
			const query = token ? `?token=${encodeURIComponent(token)}` : '';
			// eslint-disable-next-line svelte/no-navigation-without-resolve -- keeps only the ?token= query
			goto(`${resolve('/(setup)/setup')}${query}`, { replace: true });
		}
	});
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
</svelte:head>

<a class="skip-link" href="#main">{m.skip_to_content()}</a>

{#if status === null}
	<main id="main" class="center" aria-busy="true">
		<p class="muted">{m.checking_server()}</p>
	</main>
{:else if status.kind !== 'connected'}
	<main id="main" class="center">
		<ServerProblem {status} onretry={() => serverStatus.check()} />
	</main>
{:else}
	{@render children()}
{/if}

<style>
	.skip-link {
		position: absolute;
		left: var(--space-4);
		top: calc(-1 * var(--space-8));
		padding: var(--space-2) var(--space-3);
		background: var(--color-surface-raised);
		border-radius: var(--radius-md);
		box-shadow: var(--shadow-md);
		z-index: 10;
	}
	.skip-link:focus {
		top: var(--space-4);
	}
	.center {
		display: grid;
		place-items: center;
		min-height: 100dvh;
		padding: var(--space-5);
	}
	.muted {
		color: var(--color-text-muted);
	}
</style>
