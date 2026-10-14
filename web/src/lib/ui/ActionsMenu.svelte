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
	import { tick } from 'svelte';

	let { label, actions }: { label: string; actions: MenuAction[] } = $props();

	let open = $state(false);
	let root: HTMLDivElement;
	let trigger: HTMLButtonElement;
	let menu = $state<HTMLDivElement>();
	const uid = $props.id();

	const items = () => [...(menu?.querySelectorAll<HTMLElement>('[role=menuitem]') ?? [])];

	async function show() {
		open = true;
		await tick();
		items()[0]?.focus();
	}

	function hide(focusTrigger = true) {
		open = false;
		if (focusTrigger) trigger.focus();
	}

	// WAI-ARIA menu button pattern: arrows move, Home/End jump, Esc/Tab close.
	function onKeydown(e: KeyboardEvent) {
		const list = items();
		const i = list.indexOf(document.activeElement as HTMLElement);
		const move = (to: number) => list[(to + list.length) % list.length]?.focus();
		if (e.key === 'ArrowDown') move(i + 1);
		else if (e.key === 'ArrowUp') move(i - 1);
		else if (e.key === 'Home') move(0);
		else if (e.key === 'End') move(list.length - 1);
		else if (e.key === 'Escape') hide();
		else if (e.key === 'Tab') hide(false);
		else return;
		e.preventDefault();
	}

	function select(action: MenuAction) {
		hide();
		action.onselect();
	}
</script>

<svelte:window onpointerdown={(e) => open && !root.contains(e.target as Node) && hide(false)} />

<div class="wrap" bind:this={root}>
	<button
		bind:this={trigger}
		class="trigger"
		aria-label={label}
		aria-haspopup="menu"
		aria-expanded={open}
		aria-controls="menu-{uid}"
		onclick={() => (open ? hide() : show())}
		onkeydown={(e) => e.key === 'ArrowDown' && (e.preventDefault(), show())}
	>
		<EllipsisVertical size={18} aria-hidden="true" />
	</button>
	{#if open}
		<!-- svelte-ignore a11y_interactive_supports_focus -->
		<div
			class="menu"
			id="menu-{uid}"
			role="menu"
			aria-label={label}
			bind:this={menu}
			onkeydown={onKeydown}
		>
			{#each actions as action (action.label)}
				<button
					role="menuitem"
					tabindex="-1"
					class:danger={action.danger}
					onclick={() => select(action)}
				>
					{#if action.icon}<action.icon size={16} />{/if}
					{action.label}
				</button>
			{/each}
		</div>
	{/if}
</div>

<style>
	.wrap {
		position: relative;
		display: inline-block;
	}
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
	.trigger[aria-expanded='true'] {
		background: color-mix(in srgb, var(--color-text) 6%, transparent);
		color: var(--color-text);
	}
	.menu {
		position: absolute;
		right: 0;
		top: calc(100% + var(--space-1));
		z-index: 10;
		min-width: 14rem;
		padding: var(--space-1);
		background: var(--color-surface-raised);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		box-shadow: var(--shadow-lg);
		display: grid;
		animation: pop var(--duration-base) var(--ease-emphasized);
		transform-origin: top right;
	}
	@keyframes pop {
		from {
			opacity: 0;
			transform: scale(0.96) translateY(calc(-1 * var(--space-1)));
		}
	}
	[role='menuitem'] {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		min-height: 2.75rem;
		padding: 0 var(--space-3);
		border: 0;
		border-radius: var(--radius-md);
		background: transparent;
		font: inherit;
		font-size: var(--text-sm);
		color: var(--color-text);
		text-align: left;
		cursor: pointer;
	}
	[role='menuitem']:hover,
	[role='menuitem']:focus-visible {
		background: var(--color-surface-sunken);
		outline: none;
	}
	[role='menuitem'] :global(svg) {
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
