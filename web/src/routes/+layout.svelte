<script lang="ts">
	import '@fontsource-variable/inter';
	import '#lib/styles/tokens.css';
	import '#lib/styles/base.css';
	import favicon from '#lib/assets/favicon.svg';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale, locales, setLocale, type Locale } from '#lib/paraglide/runtime.js';
	import type { LayoutProps } from './$types';

	let { children }: LayoutProps = $props();

	const languageNames: Record<Locale, string> = { en: 'English', fr: 'Français' };

	$effect(() => {
		document.documentElement.lang = getLocale();
	});
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
</svelte:head>

<a class="skip-link" href="#main">{m.skip_to_content()}</a>

<header class="top">
	<label class="lang">
		<span class="visually-hidden">{m.language()}</span>
		<select
			value={getLocale()}
			onchange={(e) => setLocale(e.currentTarget.value as Locale)}
			aria-label={m.language()}
		>
			{#each locales as locale (locale)}
				<option value={locale} lang={locale}>{languageNames[locale]}</option>
			{/each}
		</select>
	</label>
</header>

<main id="main" tabindex="-1">
	{@render children()}
</main>

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
	.top {
		display: flex;
		justify-content: flex-end;
		padding: var(--space-4) var(--space-5);
	}
	select {
		font: inherit;
		font-size: var(--text-sm);
		color: var(--color-text);
		background: var(--color-surface);
		border: 1px solid var(--color-border-strong);
		border-radius: var(--radius-sm);
		padding: var(--space-1) var(--space-2);
		min-height: 2.75rem;
	}
	main {
		display: grid;
		place-items: center;
		padding: var(--space-5);
		min-height: calc(100dvh - 6rem);
	}
	main:focus {
		outline: none;
	}
</style>
