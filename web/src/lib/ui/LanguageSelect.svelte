<script lang="ts">
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale, locales, setLocale, type Locale } from '#lib/paraglide/runtime.js';

	const languageNames: Record<Locale, string> = { en: 'English', fr: 'Français' };
</script>

<select
	value={getLocale()}
	onchange={(e) => setLocale(e.currentTarget.value as Locale)}
	aria-label={m.language()}
>
	{#each locales as locale (locale)}
		<option value={locale} lang={locale}>{languageNames[locale]}</option>
	{/each}
</select>

<style>
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
</style>
