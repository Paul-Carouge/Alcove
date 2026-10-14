<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { BookImage, FileText, Folder, Image, Menu, Share2, Trash2, X } from '@lucide/svelte';
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
		{ label: m.nav_files, icon: Folder, href: resolve('/(app)'), ready: true },
		{ label: m.nav_photos, icon: Image, href: resolve('/(app)/photos'), ready: true },
		{ label: m.nav_albums, icon: BookImage, href: resolve('/(app)/albums'), ready: true },
		{ label: m.nav_documents, icon: FileText, href: resolve('/(app)/documents'), ready: true },
		{ label: m.nav_shared, icon: Share2, href: resolve('/(app)/shared'), ready: true },
		{ label: m.nav_trash, icon: Trash2, href: resolve('/(app)/trash'), ready: true }
	];

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
			<ul>
				{#each nav as item (item.label)}
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
		main {
			padding: var(--space-2) var(--space-4) calc(var(--space-6) + var(--uploads-space, 0px));
		}
	}
</style>
