<script lang="ts" module>
	import type { Component } from 'svelte';

	export interface SelectionAction {
		label: string;
		icon: Component<{ size?: number }>;
		onclick: () => void;
		disabled?: boolean;
		loading?: boolean;
		/** The main thing to do with the selection (accent fill). At most one. */
		primary?: boolean;
		/** Destructive (danger ink, not a fill: the bar stays calm). */
		danger?: boolean;
	}
</script>

<script lang="ts">
	import { LoaderCircle, X } from '@lucide/svelte';
	import { m } from '#lib/paraglide/messages.js';

	type Props = {
		/** Whether the bar is shown (a selection exists or selection mode is on). */
		open: boolean;
		/** Visible count, e.g. "3 selected"; also announced to screen readers. */
		label: string;
		actions: SelectionAction[];
		onclear: () => void;
		/** Accessible name of the close button. */
		clearLabel?: string;
	};

	let { open, label, actions, onclear, clearLabel = m.clear_selection() }: Props = $props();

	let bar = $state<HTMLDivElement>();
	let height = $state(0);
	// Plain (non-reactive) memory of the last open state, read by the deriveds below.
	let lastLabel = '';
	let wasOpen = false;

	// Keep the last label while the bar slides out, instead of flashing "0 selected".
	const shown = $derived.by(() => {
		if (open) lastLabel = label;
		return lastLabel;
	});

	const announcement = $derived.by(() => {
		if (open) {
			wasOpen = true;
			return label;
		}
		return wasOpen ? m.selection_cleared() : '';
	});

	function clear() {
		// The bar hides with its buttons: hand focus back to the page instead of losing it.
		const focusInside = bar?.contains(document.activeElement);
		onclear();
		if (focusInside) document.getElementById('main')?.focus();
	}

	const TEXT_INPUT = /^(text|search|email|password|number|url|tel|date|time|datetime-local)$/;

	// Esc clears the selection, unless something nearer (dialog, menu, text field) owns the key.
	function onKeydown(e: KeyboardEvent) {
		if (!open || e.key !== 'Escape' || e.defaultPrevented) return;
		if (document.querySelector('dialog[open]')) return;
		const t = e.target as HTMLElement | null;
		if (t instanceof HTMLTextAreaElement || t?.isContentEditable) return;
		if (t instanceof HTMLInputElement && TEXT_INPUT.test(t.type)) return;
		if (t?.closest?.('[role="menu"], [role="listbox"], [aria-expanded="true"]')) return;
		e.preventDefault();
		clear();
	}
</script>

<svelte:window onkeydown={onKeydown} />

<!-- Keeps the last rows of the page scrollable above the floating bar. -->
<div class="spacer" aria-hidden="true" style:height={open ? `${height}px` : undefined}></div>

<div class="dock">
	<div
		bind:this={bar}
		bind:offsetHeight={height}
		class="bar"
		class:open
		role="region"
		aria-label={m.selection_label()}
	>
		<div class="lead">
			<button
				class="close"
				type="button"
				aria-label={clearLabel}
				title={clearLabel}
				onclick={clear}
			>
				<X size={20} aria-hidden="true" />
			</button>
			<span class="count">{shown}</span>
		</div>
		<div class="actions">
			{#each actions as action (action.label)}
				{@const Icon = action.icon}
				<button
					type="button"
					class="action"
					class:primary={action.primary}
					class:danger={action.danger}
					disabled={action.disabled || action.loading}
					aria-busy={action.loading || undefined}
					onclick={action.onclick}
				>
					{#if action.loading}
						<LoaderCircle size={20} class="spin" aria-hidden="true" />
					{:else}
						<Icon size={20} />
					{/if}
					<span class="text">{action.label}</span>
				</button>
			{/each}
		</div>
	</div>
</div>

<p class="visually-hidden" aria-live="polite" aria-atomic="true">{announcement}</p>

<style>
	.spacer {
		height: 0;
	}
	/* Spans the content column (right of the sidebar), so the bar centres on the content. */
	.dock {
		position: fixed;
		inset-inline: var(--sidebar-width, 0px) 0;
		bottom: calc(max(var(--space-5), var(--uploads-space, 0px)) + env(safe-area-inset-bottom, 0px));
		z-index: 20;
		display: flex;
		justify-content: center;
		padding-inline: var(--space-4);
		pointer-events: none;
		container-type: inline-size;
	}
	.bar {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		max-width: 100%;
		padding: var(--space-1);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-full);
		background: var(--color-surface-raised);
		color: var(--color-text);
		box-shadow: var(--shadow-lg);
		pointer-events: auto;
		/* Closed: slid below its spot and hidden from pointer, keyboard and screen readers. */
		opacity: 0;
		transform: translateY(calc(100% + var(--space-5)));
		visibility: hidden;
		transition:
			transform var(--duration-fast) var(--ease-exit),
			opacity var(--duration-fast) var(--ease-exit),
			visibility 0s linear var(--duration-fast);
	}
	.bar.open {
		opacity: 1;
		transform: none;
		visibility: visible;
		transition:
			transform var(--duration-slow) var(--ease-emphasized),
			opacity var(--duration-base) var(--ease-standard);
	}
	.lead {
		display: flex;
		align-items: center;
		gap: var(--space-1);
		padding-inline-end: var(--space-3);
		border-inline-end: 1px solid var(--color-border);
	}
	.count {
		font-family: var(--font-display);
		font-size: var(--text-lg);
		line-height: var(--leading-tight);
		white-space: nowrap;
		font-variant-numeric: tabular-nums;
	}
	.actions {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}
	.close,
	.action {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		min-width: 2.75rem;
		min-height: 2.75rem;
		border: 0;
		border-radius: var(--radius-full);
		background: transparent;
		color: var(--color-text);
		font: inherit;
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		white-space: nowrap;
		cursor: pointer;
		transition:
			background var(--duration-fast) var(--ease-standard),
			transform var(--duration-fast) var(--ease-standard);
	}
	.action {
		padding: var(--space-2) var(--space-4);
	}
	/* Hover only where it exists: on touch the bar can appear under the last tap. */
	@media (hover: hover) {
		.close:hover,
		.action:hover:not(:disabled) {
			background: color-mix(in srgb, var(--color-text) 6%, transparent);
		}
		.action.primary:hover:not(:disabled) {
			background: var(--color-accent-hover);
		}
		.action.danger:hover:not(:disabled) {
			background: color-mix(in srgb, var(--color-danger) 10%, transparent);
		}
	}
	.close:active,
	.action:active:not(:disabled) {
		transform: scale(0.97);
	}
	.close:focus-visible,
	.action:focus-visible {
		border-radius: var(--radius-full);
	}
	.action.primary {
		background: var(--color-accent);
		color: var(--color-accent-contrast);
		box-shadow: var(--shadow-sm);
	}
	.action.danger {
		color: var(--color-danger);
	}
	.action:disabled {
		cursor: not-allowed;
		opacity: 0.55;
	}
	.action :global(svg) {
		flex: none;
	}
	.action :global(.spin) {
		animation: spin 0.8s linear infinite;
	}
	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Narrow content (phones, small windows): a rounded panel, the count on top and the
	   actions as equal columns with the label under the icon, so long labels still fit. */
	@container (max-width: 52rem) {
		.bar {
			flex-direction: column;
			align-items: stretch;
			gap: var(--space-1);
			width: min(100%, 36rem);
			padding: var(--space-2);
			border-radius: var(--radius-xl);
		}
		.lead {
			padding-inline-end: 0;
			border-inline-end: 0;
		}
		.actions {
			display: grid;
			grid-auto-columns: minmax(0, 1fr);
			grid-auto-flow: column;
			align-items: stretch;
			gap: var(--space-1);
		}
		/* Top-aligned, so icons stay on one line when a label wraps. */
		.action {
			flex-direction: column;
			justify-content: flex-start;
			gap: var(--space-1);
			min-height: 3.5rem;
			padding: var(--space-2) var(--space-1);
			border-radius: var(--radius-md);
			font-size: var(--text-xs);
		}
		.action:focus-visible {
			border-radius: var(--radius-md);
		}
		/* Long labels ("Mettre à la corbeille") wrap on two lines rather than being cut. */
		.text {
			display: -webkit-box;
			max-width: 100%;
			overflow: hidden;
			-webkit-box-orient: vertical;
			-webkit-line-clamp: 2;
			line-clamp: 2;
			line-height: var(--leading-tight);
			text-align: center;
			white-space: normal;
			overflow-wrap: break-word;
		}
	}
	@media (prefers-reduced-motion: reduce) {
		.action :global(.spin) {
			animation-duration: 2.4s;
		}
		.close:active,
		.action:active:not(:disabled) {
			transform: none;
		}
		/* Crossfade instead of a slide. */
		.bar,
		.bar.open {
			transform: none;
		}
	}
</style>
