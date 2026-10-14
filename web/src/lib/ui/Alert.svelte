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
		position: relative;
		padding: var(--space-3) var(--space-4);
		padding-inline-start: calc(var(--space-4) + var(--space-1));
		border-radius: var(--radius-md);
		font-size: var(--text-sm);
		line-height: var(--leading-normal);
		color: var(--color-text);
		border: 1px solid var(--color-border);
		background: var(--color-surface);
		overflow: hidden;
	}
	/* A quiet coloured rule on the leading edge carries the tone (plus the text and role). */
	.alert::before {
		content: '';
		position: absolute;
		inset-block: 0;
		inset-inline-start: 0;
		width: var(--space-1);
		background: var(--tone);
	}
	.danger {
		--tone: var(--color-danger);
		color: var(--color-danger);
		border-color: color-mix(in srgb, var(--color-danger) 30%, var(--color-border));
		background: color-mix(in srgb, var(--color-danger) 6%, var(--color-surface));
	}
	.success {
		--tone: var(--color-success);
		color: var(--color-success);
		border-color: color-mix(in srgb, var(--color-success) 30%, var(--color-border));
		background: color-mix(in srgb, var(--color-success) 6%, var(--color-surface));
	}
	.info {
		--tone: var(--color-accent);
		background: var(--color-accent-subtle);
		border-color: transparent;
	}
	.alert :global(p) {
		margin: 0;
	}
</style>
