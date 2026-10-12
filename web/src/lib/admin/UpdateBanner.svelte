<script lang="ts">
	import { resolve } from '$app/paths';
	import { Sparkles, X } from '@lucide/svelte';
	import { m } from '#lib/paraglide/messages.js';
	import { serverStatus } from '#lib/server-status/store.svelte.js';
	import { system } from './system.svelte.js';

	const KEY = 'alcove-update-dismissed';
	let dismissed = $state(read());

	function read() {
		try {
			return localStorage.getItem(KEY) ?? '';
		} catch {
			return '';
		}
	}

	const update = $derived(system.current?.update);
	const name = $derived(
		serverStatus.current?.kind === 'connected' ? serverStatus.current.health.name : ''
	);
	const show = $derived(!!update?.available && !!update.latest && dismissed !== update.latest);

	function later() {
		dismissed = update?.latest ?? '';
		try {
			localStorage.setItem(KEY, dismissed);
		} catch {
			// Storage unavailable: hidden for this page only.
		}
	}
</script>

{#if show && update}
	<div class="banner" role="status">
		<Sparkles size={18} aria-hidden="true" />
		<span>{m.update_banner({ name, version: update.latest ?? '' })}</span>
		<a href={resolve('/(app)/admin/system')}>{m.update_banner_view()}</a>
		<button
			class="close"
			aria-label={m.update_banner_later()}
			title={m.update_banner_later()}
			onclick={later}
		>
			<X size={16} aria-hidden="true" />
		</button>
	</div>
{/if}

<style>
	.banner {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		margin: 0 var(--space-6) var(--space-3);
		padding: var(--space-2) var(--space-2) var(--space-2) var(--space-4);
		border-radius: var(--radius-md);
		background: var(--color-accent-subtle);
		color: var(--color-text);
		font-size: var(--text-sm);
	}
	.banner :global(svg) {
		color: var(--color-accent);
		flex: none;
	}
	a {
		font-weight: var(--weight-medium);
		color: var(--color-accent);
	}
	.close {
		display: grid;
		place-items: center;
		width: 2.5rem;
		height: 2.5rem;
		margin-left: auto;
		border: 0;
		border-radius: var(--radius-sm);
		background: transparent;
		color: var(--color-text-muted);
		cursor: pointer;
	}
	.close:hover {
		background: var(--color-surface);
	}
	@media (max-width: 900px) {
		.banner {
			margin: 0 var(--space-4) var(--space-3);
		}
	}
</style>
