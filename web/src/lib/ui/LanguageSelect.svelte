<script lang="ts">
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale, locales, setLocale, type Locale } from '#lib/paraglide/runtime.js';
	import Select from './Select.svelte';

	const languageNames: Record<Locale, string> = { en: 'English', fr: 'Français' };
	const options = locales.map((l) => ({ value: l, label: languageNames[l], lang: l }));
</script>

<Select
	value={getLocale()}
	{options}
	label={m.language()}
	size="sm"
	onchange={(v) => setLocale(v as Locale)}
/>
