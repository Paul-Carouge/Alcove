<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import {
		BookImage,
		FileText,
		Folder,
		Image,
		Menu,
		Search as SearchIcon,
		Share2,
		Trash2,
		X
	} from '@lucide/svelte';
	import { session } from '#lib/auth/session.svelte.js';
	import { m } from '#lib/paraglide/messages.js';
	import { serverStatus } from '#lib/server-status/store.svelte.js';
	import StorageMeter from '#lib/drive/StorageMeter.svelte';
	import UploadPanel from '#lib/drive/UploadPanel.svelte';
	import { usage } from '#lib/drive/usage.svelte.js';
	import UpdateBanner from '#lib/admin/UpdateBanner.svelte';
	import { system } from '#lib/admin/system.svelte.js';
	import Logo from '#lib/ui/Logo.svelte';
	import Credit from '#lib/ui/Credit.svelte';
	import UserMenu from '#lib/ui/UserMenu.svelte';
	import type { LayoutProps } from './$types';

	let { children }: LayoutProps = $props();
	let drawerOpen = $state(false);

	const health = $derived(
		serverStatus.current?.kind === 'connected' ? serverStatus.current.health : null
	);

	// Sections arrive phase by phase (see docs/ROADMAP.md); upcoming ones are shown, disabled.
	const nav = [
		{ label: m.nav_files, icon: Folder, href: resolve('/(app)'), ready: true, group: 0 },
		{ label: m.nav_photos, icon: Image, href: resolve('/(app)/photos'), ready: true, group: 0 },
		{ label: m.nav_albums, icon: BookImage, href: resolve('/(app)/albums'), ready: true, group: 0 },
		{
			label: m.nav_documents,
			icon: FileText,
			href: resolve('/(app)/documents'),
			ready: true,
			group: 0
		},
		{ label: m.nav_shared, icon: Share2, href: resolve('/(app)/shared'), ready: true, group: 1 },
		{ label: m.nav_trash, icon: Trash2, href: resolve('/(app)/trash'), ready: true, group: 1 }
	];
	const groups = [
		{ label: m.nav_group_library, items: nav.filter((i) => i.group === 0) },
		{ label: m.nav_group_more, items: nav.filter((i) => i.group === 1) }
	];

	// Global search: ⌘K / Ctrl+K or "/" focuses it from anywhere.
	let searchInput = $state<HTMLInputElement>();
	let query = $state('');
	const isMac = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform);
	function onGlobalKey(e: KeyboardEvent) {
		const typing =
			e.target instanceof HTMLInputElement ||
			e.target instanceof HTMLTextAreaElement ||
			(e.target as HTMLElement)?.isContentEditable;
		if ((e.key === 'k' && (e.metaKey || e.ctrlKey)) || (e.key === '/' && !typing)) {
			if (document.querySelector('dialog[open]')) return;
			e.preventDefault();
			searchInput?.focus();
			searchInput?.select();
		}
	}
	function search(e: SubmitEvent) {
		e.preventDefault();
		const q = query.trim();
		if (!q) return;
		searchInput?.blur();
		// eslint-disable-next-line svelte/no-navigation-without-resolve -- resolved path plus a query
		goto(`${resolve('/(app)/search')}?q=${encodeURIComponent(q)}`);
	}

	// Token revoked or expired elsewhere: back to the login page.
	$effect(() => {
		if (!session.isSignedIn) goto(resolve('/(public)/login'), { replace: true });
	});

	$effect(() => {
		usage.start();
		return () => usage.stop();
	});

	$effect(() => {
		if (session.isAdmin) system.load();
	});

	// Close the mobile drawer after navigating.
	$effect(() => {
		void page.url.pathname;
		drawerOpen = false;
	});
</script>

<div class="shell">
	<aside class="sidebar" class:open={drawerOpen} aria-label={m.nav_label()}>
		<div class="sidebar-head">
			<a class="brand" href={resolve('/(app)')}><Logo name={health?.name} /></a>
			<button
				class="icon-btn close"
				aria-label={m.close_menu()}
				onclick={() => (drawerOpen = false)}
			>
				<X size={20} aria-hidden="true" />
			</button>
		</div>
		<nav>
			{#each groups as group (group.label)}
				<h2 class="group">{group.label()}</h2>
				<ul>
					{#each group.items as item (item.label)}
						<li>
							{#if item.ready && item.href}
								<a
									href={item.href}
									class="nav-item"
									aria-current={page.url.pathname === item.href ||
									(item.href !== resolve('/(app)') &&
										page.url.pathname.startsWith(item.href + '/')) ||
									(item.href === resolve('/(app)') && page.url.pathname.startsWith('/folders/'))
										? 'page'
										: undefined}
								>
									<item.icon size={18} aria-hidden="true" />
									<span>{item.label()}</span>
								</a>
							{:else}
								<span class="nav-item disabled" aria-disabled="true">
									<item.icon size={18} aria-hidden="true" />
									<span>{item.label()}</span>
									<span class="soon">{m.coming_soon()}</span>
								</span>
							{/if}
						</li>
					{/each}
				</ul>
			{/each}
		</nav>
		<div class="bottom">
			<StorageMeter />
			<footer class="version">
				{#if health}<span>{m.server_info({ name: health.name, version: health.version })}</span
					>{/if}
				<Credit />
			</footer>
		</div>
	</aside>

	{#if drawerOpen}
		<button class="scrim" aria-label={m.close_menu()} onclick={() => (drawerOpen = false)}></button>
	{/if}

	<div class="content">
		<header class="topbar">
			<button
				class="icon-btn burger"
				aria-label={m.open_menu()}
				onclick={() => (drawerOpen = true)}
			>
				<Menu size={20} aria-hidden="true" />
			</button>
			<form class="global-search" role="search" onsubmit={search}>
				<SearchIcon size={16} aria-hidden="true" />
				<input
					bind:this={searchInput}
					bind:value={query}
					type="search"
					placeholder={m.search_everywhere()}
					aria-label={m.search_everywhere()}
					autocomplete="off"
				/>
				<kbd aria-hidden="true">{isMac ? '⌘K' : 'Ctrl K'}</kbd>
			</form>
			<div class="spacer"></div>
			{#if session.user}
				<UserMenu
					name={session.user.name}
					email={session.user.email}
					onsignout={() => session.signOut()}
				/>
			{/if}
		</header>
		{#if session.isAdmin}<UpdateBanner />{/if}
		<main id="main" tabindex="-1">
			{@render children()}
		</main>
	</div>
</div>

<UploadPanel />
<svelte:window onkeydown={onGlobalKey} />

<style>
	.shell {
		display: grid;
		grid-template-columns: 16rem 1fr;
		min-height: 100dvh;
	}
	.sidebar {
		position: sticky;
		top: 0;
		height: 100dvh;
		display: flex;
		flex-direction: column;
		gap: var(--space-5);
		padding: var(--space-4) var(--space-3);
		background: var(--color-surface);
		border-right: 1px solid var(--color-border);
	}
	.sidebar-head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: var(--space-1) var(--space-2);
	}
	.brand {
		text-decoration: none;
		border-radius: var(--radius-md);
	}
	ul {
		list-style: none;
		margin: 0;
		padding: 0;
		display: grid;
		gap: 2px;
	}
	.nav-item {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		min-height: 2.75rem;
		padding: 0 var(--space-3);
		border-radius: var(--radius-md);
		color: var(--color-text-muted);
		text-decoration: none;
		font-weight: var(--weight-medium);
		transition:
			background var(--duration-fast) var(--ease-standard),
			color var(--duration-fast) var(--ease-standard);
	}
	a.nav-item:hover {
		background: var(--color-surface-sunken);
		color: var(--color-text);
	}
	.nav-item[aria-current='page'],
	a.nav-item[aria-current='page']:hover {
		background: var(--color-accent-subtle);
		color: var(--color-accent);
	}
	.nav-item.disabled {
		cursor: default;
	}
	.soon {
		margin-left: auto;
		font-size: var(--text-xs);
		font-weight: var(--weight-medium);
		padding: 0 var(--space-2);
		border-radius: var(--radius-full);
		background: var(--color-surface-sunken);
		color: var(--color-text-muted);
	}
	.bottom {
		margin-top: auto;
		display: grid;
		gap: var(--space-3);
	}
	.version {
		display: grid;
		gap: 2px;
		padding: 0 var(--space-3);
		font-size: var(--text-xs);
		color: var(--color-text-muted);
	}
	.content {
		display: flex;
		flex-direction: column;
		min-width: 0;
	}
	.topbar {
		position: sticky;
		top: 0;
		z-index: 5;
		display: flex;
		align-items: center;
		gap: var(--space-3);
		min-height: 4rem;
		padding: 0 var(--space-5);
		background: color-mix(in srgb, var(--color-bg) 85%, transparent);
		backdrop-filter: blur(8px);
	}
	.spacer {
		flex: 1;
	}
	.group {
		margin: var(--space-4) 0 var(--space-1);
		padding: 0 var(--space-3);
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		font-weight: var(--weight-medium);
		letter-spacing: 0.04em;
		text-transform: uppercase;
	}
	.group:first-child {
		margin-top: 0;
	}
	.global-search {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		width: min(100%, 30rem);
		min-height: 2.5rem;
		padding: 0 var(--space-2) 0 var(--space-3);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-full);
		background: var(--color-surface);
		color: var(--color-text-muted);
		transition:
			border-color var(--duration-fast) var(--ease-standard),
			box-shadow var(--duration-fast) var(--ease-standard);
	}
	.global-search:focus-within {
		border-color: var(--color-accent);
		box-shadow: 0 0 0 3px var(--color-accent-subtle);
	}
	.global-search input {
		flex: 1;
		min-width: 0;
		border: 0;
		background: transparent;
		color: var(--color-text);
		font: inherit;
		font-size: var(--text-sm);
		outline: none;
	}
	kbd {
		padding: 1px var(--space-2);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-sm);
		background: var(--color-surface-sunken);
		color: var(--color-text-muted);
		font: inherit;
		font-size: var(--text-xs);
	}
	.icon-btn {
		display: grid;
		place-items: center;
		width: 2.75rem;
		height: 2.75rem;
		border: 0;
		border-radius: var(--radius-md);
		background: transparent;
		color: var(--color-text);
		cursor: pointer;
	}
	.icon-btn:hover {
		background: var(--color-surface-sunken);
	}
	.burger,
	.close,
	.scrim {
		display: none;
	}
	main {
		flex: 1;
		width: 100%;
		max-width: 80rem;
		margin-inline: auto;
		padding: var(--space-2) var(--space-6) calc(var(--space-7) + var(--uploads-space, 0px));
	}
	main:focus {
		outline: none;
	}

	@media (max-width: 900px) {
		.shell {
			grid-template-columns: 1fr;
		}
		.sidebar {
			position: fixed;
			inset: 0 auto 0 0;
			z-index: 30;
			width: min(18rem, 85vw);
			box-shadow: var(--shadow-lg);
			transform: translateX(-100%);
			visibility: hidden;
			transition:
				transform var(--duration-base) var(--ease-emphasized),
				visibility 0s linear var(--duration-base);
		}
		.sidebar.open {
			transform: none;
			visibility: visible;
			transition: transform var(--duration-base) var(--ease-emphasized);
		}
		.burger,
		.close {
			display: grid;
		}
		.scrim {
			display: block;
			position: fixed;
			inset: 0;
			z-index: 25;
			border: 0;
			background: var(--color-overlay);
		}
		.topbar {
			padding: 0 var(--space-3);
		}
		kbd {
			display: none;
		}
		main {
			padding: var(--space-2) var(--space-4) calc(var(--space-6) + var(--uploads-space, 0px));
		}
	}
</style>
