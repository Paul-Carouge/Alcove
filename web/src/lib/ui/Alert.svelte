<script lang="ts">
	import type { Snippet } from 'svelte';

	let { tone = 'danger', children }: { tone?: 'danger' | 'success' | 'info'; children: Snippet } =
		$props();
</script>

<!-- Errors interrupt (role=alert); confirmations are announced politely. -->
<div class="alert {tone}" role={tone === 'danger' ? 'alert' : 'status'}>
	{@render children()}
</div>

<style>
	.alert {
		padding: var(--space-3);
		border-radius: var(--radius-md);
		font-size: var(--text-sm);
		border: 1px solid currentColor;
	}
	.danger {
		color: var(--color-danger);
	}
	.success {
		color: var(--color-success);
	}
	.info {
		color: var(--color-text);
		border-color: var(--color-border);
		background: var(--color-accent-subtle);
	}
</style>
