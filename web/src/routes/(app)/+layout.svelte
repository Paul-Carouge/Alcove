<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { session } from '#lib/auth/session.svelte.js';
	import { m } from '#lib/paraglide/messages.js';
	import { serverStatus } from '#lib/server-status/store.svelte.js';
	import Button from '#lib/ui/Button.svelte';
	import LanguageSelect from '#lib/ui/LanguageSelect.svelte';
	import type { LayoutProps } from './$types';

	let { children }: LayoutProps = $props();

	const appName = $derived(
		serverStatus.current?.kind === 'connected' ? serverStatus.current.health.name : ''
	);

	// Token revoked or expired elsewhere: back to the login page.
	$effect(() => {
		if (!session.isSignedIn) goto(resolve('/(public)/login'), { replaceState: true });
	});

	function signOut() {
		session.signOut();
	}
</script>

<header class="bar">
	<a class="brand" href={resolve('/(app)')}>{appName}</a>
	<div class="actions">
		{#if session.user}
			<span class="who">{m.signed_in_as({ email: session.user.email })}</span>
		{/if}
		<LanguageSelect />
		<Button variant="secondary" onclick={signOut}>{m.sign_out_button()}</Button>
	</div>
</header>

<main id="main" tabindex="-1">
	{@render children()}
</main>

<style>
	.bar {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-4);
		padding: var(--space-3) var(--space-5);
		border-bottom: 1px solid var(--color-border);
		background: var(--color-surface);
	}
	.brand {
		font-weight: var(--weight-semibold);
		font-size: var(--text-lg);
		color: var(--color-text);
		text-decoration: none;
	}
	.actions {
		display: flex;
		align-items: center;
		gap: var(--space-3);
	}
	.who {
		font-size: var(--text-sm);
		color: var(--color-text-muted);
	}
	@media (max-width: 600px) {
		.who {
			display: none;
		}
	}
	main {
		padding: var(--space-5);
		max-width: 75rem;
		margin-inline: auto;
	}
	main:focus {
		outline: none;
	}
</style>
