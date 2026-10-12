<script lang="ts">
	import type { Snippet } from 'svelte';

	let {
		open = $bindable(false),
		title,
		children,
		onclose
	}: { open?: boolean; title: string; children: Snippet; onclose?: () => void } = $props();

	let dialog: HTMLDialogElement;
	const uid = $props.id();

	// Native <dialog>: focus trap, Esc to close and inert background for free.
	$effect(() => {
		if (open && !dialog.open) dialog.showModal();
		if (!open && dialog.open) dialog.close();
	});
</script>

<dialog
	bind:this={dialog}
	aria-labelledby="dialog-title-{uid}"
	onclose={() => {
		open = false;
		onclose?.();
	}}
	onclick={(e) => e.target === dialog && dialog.close()}
>
	<div class="box">
		<h2 id="dialog-title-{uid}">{title}</h2>
		{#if open}{@render children()}{/if}
	</div>
</dialog>

<style>
	dialog {
		width: min(100% - 2 * var(--space-4), 26rem);
		padding: 0;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface-raised);
		color: var(--color-text);
		box-shadow: var(--shadow-lg);
	}
	dialog[open] {
		animation: enter var(--duration-base) var(--ease-emphasized);
	}
	dialog::backdrop {
		background: var(--color-overlay);
	}
	@keyframes enter {
		from {
			opacity: 0;
			transform: translateY(8px) scale(0.98);
		}
	}
	.box {
		display: grid;
		gap: var(--space-4);
		padding: var(--space-5);
	}
	h2 {
		font-size: var(--text-lg);
	}
</style>
