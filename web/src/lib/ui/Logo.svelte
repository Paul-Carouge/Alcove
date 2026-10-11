<script lang="ts">
	let { name = '', size = 32 }: { name?: string; size?: number } = $props();
</script>

<span class="logo">
	<svg width={size} height={size} viewBox="0 0 32 32" aria-hidden="true">
		<rect width="32" height="32" rx="9" fill="var(--color-accent)" />
		<path
			d="M9 24V15a7 7 0 0 1 14 0v9"
			fill="none"
			stroke="var(--color-accent-contrast)"
			stroke-width="2.6"
			stroke-linecap="round"
		/>
		<path d="M13 24v-7a3 3 0 0 1 6 0v7" fill="var(--color-accent-contrast)" opacity="0.35" />
	</svg>
	{#if name}<span class="name">{name}</span>{/if}
</span>

<style>
	.logo {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
	}
	svg {
		flex: none;
	}
	.name {
		font-weight: var(--weight-semibold);
		font-size: var(--text-lg);
		letter-spacing: -0.01em;
		color: var(--color-text);
	}
</style>
