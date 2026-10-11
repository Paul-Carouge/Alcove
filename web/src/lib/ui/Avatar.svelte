<script lang="ts">
	let {
		name = '',
		email = '',
		size = 32
	}: { name?: string; email?: string; size?: number } = $props();

	const initials = $derived(
		(name.trim() || email)
			.split(/[\s@._-]+/)
			.filter(Boolean)
			.slice(0, 2)
			.map((p) => p[0]!.toUpperCase())
			.join('')
	);
</script>

<span class="avatar" style:--size="{size}px" aria-hidden="true">{initials}</span>

<style>
	.avatar {
		display: inline-grid;
		place-items: center;
		flex: none;
		width: var(--size);
		height: var(--size);
		border-radius: var(--radius-full);
		background: var(--color-accent-subtle);
		color: var(--color-accent);
		font-size: calc(var(--size) * 0.4);
		font-weight: var(--weight-semibold);
	}
</style>
