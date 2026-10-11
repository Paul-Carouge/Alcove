<script lang="ts">
	/* eslint-disable svelte/no-navigation-without-resolve -- external link to the author's profile */
	import { AUTHOR, AUTHOR_URL } from '#lib/brand.js';
	import { m } from '#lib/paraglide/messages.js';
</script>

<span class="credit">
	{m.made_by()}
	<a href={AUTHOR_URL} target="_blank" rel="noopener noreferrer">{AUTHOR}</a>
</span>

<style>
	.credit {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
	}
	a {
		color: inherit;
		text-decoration: underline;
		text-decoration-color: var(--color-border-strong);
		text-underline-offset: 2px;
	}
	a:hover {
		color: var(--color-text);
	}
</style>
