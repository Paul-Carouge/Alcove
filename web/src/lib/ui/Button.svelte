<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { HTMLButtonAttributes } from 'svelte/elements';

	type Props = HTMLButtonAttributes & {
		variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
		loading?: boolean;
		children: Snippet;
	};

	let {
		variant = 'primary',
		loading = false,
		disabled,
		type = 'button',
		children,
		...rest
	}: Props = $props();
</script>

<button
	{...rest}
	{type}
	class="btn {variant}"
	disabled={disabled || loading}
	aria-busy={loading || undefined}
>
	{#if loading}<span class="spinner" aria-hidden="true"></span>{/if}
	<span class="label" class:hidden={loading}>{@render children()}</span>
</button>

<style>
	.btn {
		position: relative;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		min-height: 2.75rem;
		padding: var(--space-2) var(--space-4);
		font: inherit;
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		letter-spacing: 0.005em;
		white-space: nowrap;
		border-radius: var(--radius-md);
		border: 1px solid transparent;
		cursor: pointer;
		transition:
			background var(--duration-fast) var(--ease-standard),
			border-color var(--duration-fast) var(--ease-standard),
			box-shadow var(--duration-fast) var(--ease-standard),
			transform var(--duration-fast) var(--ease-standard);
	}
	.btn:active:not(:disabled) {
		transform: scale(0.98);
	}
	.btn:disabled {
		cursor: not-allowed;
		opacity: 0.55;
	}
	.btn :global(svg) {
		flex: none;
	}
	.primary {
		background: var(--color-accent);
		color: var(--color-accent-contrast);
		box-shadow: var(--shadow-sm);
	}
	.primary:hover:not(:disabled) {
		background: var(--color-accent-hover);
		box-shadow: var(--shadow-md);
	}
	.secondary {
		background: var(--color-surface);
		color: var(--color-text);
		border-color: var(--color-border);
		box-shadow: var(--shadow-sm);
	}
	.secondary:hover:not(:disabled) {
		border-color: var(--color-border-strong);
		background: var(--color-surface-raised);
	}
	.ghost {
		background: transparent;
		color: var(--color-text);
	}
	.ghost:hover:not(:disabled) {
		background: color-mix(in srgb, var(--color-text) 6%, transparent);
	}
	.danger {
		background: var(--color-danger);
		color: var(--color-danger-contrast);
		box-shadow: var(--shadow-sm);
	}
	.danger:hover:not(:disabled) {
		background: color-mix(in srgb, var(--color-danger) 88%, var(--color-text));
	}
	.label {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
	}
	.hidden {
		visibility: hidden;
	}
	.spinner {
		position: absolute;
		width: 1.1rem;
		height: 1.1rem;
		border: 2px solid currentColor;
		border-right-color: transparent;
		border-radius: var(--radius-full);
		animation: spin 0.8s linear infinite;
	}
	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}
	@media (prefers-reduced-motion: reduce) {
		.spinner {
			animation-duration: 2.4s;
		}
		.btn:active:not(:disabled) {
			transform: none;
		}
	}
</style>
