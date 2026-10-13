<script lang="ts">
	// Text around the words that matched, as returned by the search API: no HTML is interpreted.
	let { segments }: { segments: { text: string; hit?: boolean }[] } = $props();
</script>

<span class="snippet"
	>{#each segments as s, i (i)}{#if s.hit}<mark>{s.text}</mark>{:else}{s.text}{/if}{/each}</span
>

<style>
	.snippet {
		display: -webkit-box;
		-webkit-line-clamp: 2;
		line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
		color: var(--color-text-muted);
		font-size: var(--text-sm);
		line-height: var(--leading-normal);
	}
	mark {
		padding: 0 2px;
		border-radius: 3px;
		background: var(--color-accent-subtle);
		color: var(--color-text);
		font-weight: var(--weight-medium);
	}
</style>
