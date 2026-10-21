<script lang="ts" module>
	export interface SelectOption<T extends string = string> {
		value: T;
		label: string;
		/** Language of the label, e.g. for a language picker. */
		lang?: string;
	}
</script>

<script lang="ts" generics="T extends string">
	import { Check, ChevronDown, ChevronUp } from '@lucide/svelte';
	import { Select } from 'bits-ui';
	import { tick } from 'svelte';

	// bits-ui implements the WAI-ARIA select-only combobox (keyboard, typeahead, collision-aware
	// placement): the list can be styled, which a native <select> popup cannot, notably in Firefox.
	let {
		value = $bindable(),
		options,
		label,
		labelledby,
		id,
		size = 'md',
		onchange
	}: {
		value: T;
		options: SelectOption<T>[];
		/** Accessible name, unless `labelledby` points to a visible label. */
		label?: string;
		labelledby?: string;
		id?: string;
		size?: 'sm' | 'md';
		onchange?: (value: T) => void;
	} = $props();

	const selected = $derived(options.find((o) => o.value === value));

	let trigger = $state<HTMLElement | null>(null);
	// A modal <dialog> sits in the top layer and makes <body> inert: render the list inside it.
	const portalTarget = $derived(trigger?.closest('dialog') ?? 'body');
	const uid = $props.id();
	const listId = `${uid}-list`;
	let open = $state(false);
	let highlighted = $state<string>();

	function choose(chosenValue: string) {
		const option = options.find((o) => o.value === chosenValue);
		if (!option || option.value === value) return;
		value = option.value;
		onchange?.(option.value);
	}

	// Two keys of the WAI-ARIA select-only combobox that bits-ui leaves out: Tab commits the
	// highlighted option, Home/End open the closed list on the first/last option.
	async function completeKeyboardPattern(e: KeyboardEvent) {
		if (e.key === 'Tab' && open && highlighted !== undefined) choose(highlighted);
		if ((e.key === 'Home' || e.key === 'End') && !open && options.length) {
			e.preventDefault();
			open = true;
			await tick();
			// Replayed once the options exist, bits-ui moves the highlight itself.
			trigger?.dispatchEvent(new KeyboardEvent('keydown', { key: e.key, bubbles: true }));
		}
	}
</script>

<Select.Root type="single" {value} onValueChange={choose} items={options} bind:open>
	<Select.Trigger
		bind:ref={trigger}
		{id}
		role="combobox"
		aria-controls={listId}
		aria-label={labelledby ? undefined : label}
		aria-labelledby={labelledby}
		onkeydown={completeKeyboardPattern}
	>
		{#snippet child({ props })}
			<button {...props} class="select {size}">
				<span class="value" lang={selected?.lang}>{selected?.label ?? ''}</span>
				<ChevronDown size={16} aria-hidden="true" class="chevron" />
			</button>
		{/snippet}
	</Select.Trigger>
	<Select.Portal to={portalTarget}>
		<Select.Content
			id={listId}
			strategy="fixed"
			sideOffset={4}
			collisionPadding={8}
			aria-label={label}
			aria-labelledby={labelledby}
		>
			{#snippet child({ wrapperProps, props })}
				<div {...wrapperProps}>
					<div {...props} class="list">
						<Select.ScrollUpButton class="scroll" aria-hidden="true">
							<ChevronUp size={16} />
						</Select.ScrollUpButton>
						<Select.Viewport>
							{#each options as o (o.value)}
								<Select.Item
									value={o.value}
									label={o.label}
									onHighlight={() => (highlighted = o.value)}
								>
									{#snippet child({ props: itemProps, selected: isSelected })}
										<div {...itemProps} class="option" lang={o.lang}>
											<span>{o.label}</span>
											{#if isSelected}<Check size={16} aria-hidden="true" />{/if}
										</div>
									{/snippet}
								</Select.Item>
							{/each}
						</Select.Viewport>
						<Select.ScrollDownButton class="scroll" aria-hidden="true">
							<ChevronDown size={16} />
						</Select.ScrollDownButton>
					</div>
				</div>
			{/snippet}
		</Select.Content>
	</Select.Portal>
</Select.Root>

<style>
	.select {
		display: inline-flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-2);
		min-height: 2.75rem;
		min-width: 8rem;
		padding: 0 var(--space-3);
		border: 1px solid var(--color-border-strong);
		border-radius: var(--radius-md);
		background: var(--color-surface);
		color: var(--color-text);
		font: inherit;
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		text-align: start;
		cursor: pointer;
		user-select: none;
		transition:
			border-color var(--duration-fast) var(--ease-standard),
			box-shadow var(--duration-fast) var(--ease-standard);
	}
	.select.sm {
		min-width: 6rem;
		padding: 0 var(--space-2) 0 var(--space-3);
		border-color: var(--color-border);
	}
	.select:hover {
		border-color: var(--color-text-muted);
	}
	.select:focus-visible {
		outline: none;
		border-color: var(--color-focus);
		box-shadow:
			0 0 0 1px var(--color-focus),
			0 0 0 4px var(--color-accent-subtle);
	}
	.select[data-state='open'] {
		border-color: var(--color-accent);
		box-shadow: 0 0 0 4px var(--color-accent-subtle);
	}
	.value {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.select :global(.chevron) {
		flex-shrink: 0;
		color: var(--color-text-muted);
		transition: transform var(--duration-fast) var(--ease-standard);
	}
	.select[data-state='open'] :global(.chevron) {
		transform: rotate(180deg);
	}
	.list {
		z-index: 50;
		min-width: var(--bits-floating-anchor-width);
		max-width: calc(100vw - 2 * var(--space-4));
		max-height: min(20rem, var(--bits-floating-available-height));
		padding: var(--space-1);
		background: var(--color-surface-raised);
		color: var(--color-text);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		box-shadow: var(--shadow-lg);
		animation: pop var(--duration-base) var(--ease-emphasized);
		transform-origin: var(--bits-floating-transform-origin);
	}
	@keyframes pop {
		from {
			opacity: 0;
			transform: scale(0.97);
		}
	}
	.option {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
		min-height: 2.75rem;
		padding: 0 var(--space-3);
		border-radius: var(--radius-sm);
		font-size: var(--text-sm);
		white-space: nowrap;
		cursor: pointer;
		outline: none;
	}
	.list :global(.scroll) {
		display: grid;
		place-items: center;
		min-height: var(--space-6);
		color: var(--color-text-muted);
		cursor: default;
	}
	.option[data-highlighted] {
		background: var(--color-surface-sunken);
	}
	.option[data-selected] {
		color: var(--color-accent);
		font-weight: var(--weight-medium);
	}
	@media (prefers-reduced-motion: reduce) {
		.list,
		.select :global(.chevron) {
			animation: none;
			transition: none;
		}
	}
</style>
