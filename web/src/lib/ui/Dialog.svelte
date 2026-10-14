<script lang="ts">
	import type { Snippet } from 'svelte';

	let {
		open = $bindable(false),
		title,
		children,
		onclose,
		wide = false
	}: {
		open?: boolean;
		title: string;
		children: Snippet;
		onclose?: () => void;
		/** For reading content (e.g. a document's text) rather than a short form. */
		wide?: boolean;
	} = $props();

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
	class:wide
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
		width: min(100% - 2 * var(--space-4), 28rem);
		max-height: calc(100dvh - 2 * var(--space-5));
		padding: 0;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-xl);
		background: var(--color-surface-raised);
		color: var(--color-text);
		box-shadow: var(--shadow-lg);
		overflow: auto;
		overscroll-behavior: contain;
	}
	dialog.wide {
		width: min(100% - 2 * var(--space-4), 48rem);
	}
	dialog[open] {
		animation: enter var(--duration-slow) var(--ease-emphasized);
	}
	dialog::backdrop {
		background: var(--color-overlay);
		backdrop-filter: blur(var(--space-1));
		animation: fade var(--duration-base) var(--ease-standard);
	}
	@keyframes enter {
		from {
			opacity: 0;
			transform: translateY(var(--space-2)) scale(0.98);
		}
	}
	@keyframes fade {
		from {
			opacity: 0;
		}
	}
	.box {
		display: grid;
		gap: var(--space-5);
		padding: var(--space-6);
	}
	h2 {
		font-size: var(--text-xl);
		padding-inline-end: var(--space-4);
	}
	/* Dialogs end with their buttons: a little more air above them. */
	dialog .box :global(.actions) {
		margin-top: var(--space-2);
	}

	/* Phones: a bottom sheet, within thumb reach. */
	@media (max-width: 600px) {
		dialog,
		dialog.wide {
			width: 100%;
			max-width: 100%;
			max-height: calc(100dvh - var(--space-7));
			margin: auto 0 0;
			border-radius: var(--radius-xl) var(--radius-xl) 0 0;
			border-bottom: 0;
		}
		dialog[open] {
			animation-name: sheet;
		}
		.box {
			gap: var(--space-4);
			padding: var(--space-5) var(--space-4) calc(var(--space-5) + env(safe-area-inset-bottom));
		}
		dialog .box :global(.actions > .btn) {
			flex: 1;
		}
		/* Grab handle: a visual hint that this is a sheet. */
		.box::before {
			content: '';
			justify-self: center;
			width: var(--space-6);
			height: var(--space-1);
			margin-top: calc(-1 * var(--space-2));
			border-radius: var(--radius-full);
			background: var(--color-border-strong);
		}
		@keyframes sheet {
			from {
				transform: translateY(100%);
			}
		}
	}
</style>
