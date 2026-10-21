<script lang="ts" module>
	import type { Component } from 'svelte';

	export interface MenuAction {
		label: string;
		icon?: Component<{ size?: number }>;
		danger?: boolean;
		onselect: () => void;
	}
</script>

<script lang="ts">
	import { EllipsisVertical } from '@lucide/svelte';
	import { DropdownMenu } from 'bits-ui';

	// bits-ui implements the WAI-ARIA menu button: arrows, Home/End, typeahead, Esc and focus return.
	let { label, actions }: { label: string; actions: MenuAction[] } = $props();

	let trigger = $state<HTMLElement | null>(null);
	// A modal <dialog> sits in the top layer and makes <body> inert: render the menu inside it.
	const portalTarget = $derived(trigger?.closest('dialog') ?? 'body');
</script>

<DropdownMenu.Root>
	<DropdownMenu.Trigger bind:ref={trigger} aria-label={label}>
		{#snippet child({ props })}
			<button {...props} class="trigger">
				<EllipsisVertical size={18} aria-hidden="true" />
			</button>
		{/snippet}
	</DropdownMenu.Trigger>
	<DropdownMenu.Portal to={portalTarget}>
		<DropdownMenu.Content align="end" sideOffset={4} collisionPadding={8} aria-label={label}>
			{#snippet child({ wrapperProps, props })}
				<div {...wrapperProps}>
					<div {...props} class="menu">
						{#each actions as action (action.label)}
							<DropdownMenu.Item onSelect={action.onselect}>
								{#snippet child({ props: itemProps })}
									<div {...itemProps} class="item" class:danger={action.danger}>
										{#if action.icon}<action.icon size={16} />{/if}
										{action.label}
									</div>
								{/snippet}
							</DropdownMenu.Item>
						{/each}
					</div>
				</div>
			{/snippet}
		</DropdownMenu.Content>
	</DropdownMenu.Portal>
</DropdownMenu.Root>

<style>
	.trigger {
		display: grid;
		place-items: center;
		width: 2.75rem;
		height: 2.75rem;
		border: 0;
		border-radius: var(--radius-md);
		background: transparent;
		color: var(--color-text-muted);
		cursor: pointer;
	}
	.trigger:hover,
	.trigger[data-state='open'] {
		background: color-mix(in srgb, var(--color-text) 6%, transparent);
		color: var(--color-text);
	}
	.menu {
		z-index: 50;
		display: grid;
		min-width: 14rem;
		max-height: var(--bits-floating-available-height);
		overflow-y: auto;
		padding: var(--space-1);
		background: var(--color-surface-raised);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		box-shadow: var(--shadow-lg);
		outline: none;
		animation: pop var(--duration-base) var(--ease-emphasized);
		transform-origin: var(--bits-floating-transform-origin);
	}
	@keyframes pop {
		from {
			opacity: 0;
			transform: scale(0.96);
		}
	}
	.item {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		min-height: 2.75rem;
		padding: 0 var(--space-3);
		border-radius: var(--radius-md);
		font-size: var(--text-sm);
		color: var(--color-text);
		cursor: pointer;
		outline: none;
	}
	.item[data-highlighted] {
		background: var(--color-surface-sunken);
	}
	.item :global(svg) {
		flex: none;
		color: var(--color-text-muted);
	}
	.danger,
	.danger :global(svg) {
		color: var(--color-danger);
	}
	@media (prefers-reduced-motion: reduce) {
		.menu {
			animation: none;
		}
	}
</style>
