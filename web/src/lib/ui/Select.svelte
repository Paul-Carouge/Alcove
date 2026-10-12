<script lang="ts" module>
	export interface SelectOption<T extends string = string> {
		value: T;
		label: string;
		/** Language of the label, e.g. for a language picker. */
		lang?: string;
	}
</script>

<script lang="ts" generics="T extends string">
	import { Check, ChevronDown } from '@lucide/svelte';
	import { tick } from 'svelte';

	// WAI-ARIA "select-only combobox": the list can be styled (a native <select> popup cannot,
	// notably in Firefox) while keeping the keyboard and screen-reader behaviour of a select.
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

	const uid = $props.id();
	let open = $state(false);
	let active = $state(0);
	let trigger: HTMLDivElement;
	let list = $state<HTMLUListElement>();
	let place = $state({ top: 0, left: 0, width: 0, up: false, max: 320 });
	let typed = '';
	let typedAt = 0;

	const selected = $derived(options.find((o) => o.value === value));

	function position() {
		const r = trigger.getBoundingClientRect();
		const below = window.innerHeight - r.bottom - 8;
		const above = r.top - 8;
		const up = below < 200 && above > below;
		// Keep the list on screen when it is wider than the field near the right edge.
		const w = list?.offsetWidth ?? r.width;
		const left = r.left + w > window.innerWidth - 8 ? Math.max(8, r.right - w) : r.left;
		place = {
			top: up ? r.top - 4 : r.bottom + 4,
			left,
			width: r.width,
			up,
			max: Math.min(320, Math.max(120, up ? above : below))
		};
	}

	async function show() {
		if (open || !options.length) return;
		active = Math.max(
			0,
			options.findIndex((o) => o.value === value)
		);
		position();
		open = true;
		await tick();
		try {
			list?.showPopover?.();
		} catch {
			// Popover API missing: the list is still positioned, just not in the top layer.
		}
		position(); // again, now that the list's width is known
		scrollActive();
	}

	function hide() {
		if (!open) return;
		try {
			list?.hidePopover?.();
		} catch {
			// Not shown as a popover.
		}
		open = false;
	}

	function choose(i: number) {
		const o = options[i];
		hide();
		trigger.focus();
		if (!o || o.value === value) return;
		value = o.value;
		onchange?.(o.value);
	}

	async function scrollActive() {
		await tick();
		list?.querySelector<HTMLElement>(`#${CSS.escape(`${uid}-o${active}`)}`)?.scrollIntoView({
			block: 'nearest'
		});
	}

	function move(to: number) {
		active = Math.min(options.length - 1, Math.max(0, to));
		scrollActive();
	}

	// Typing letters jumps to the next option starting with them, like a native select.
	function typeahead(key: string) {
		const now = Date.now();
		typed = now - typedAt > 700 ? key : typed + key;
		typedAt = now;
		const q = typed.toLocaleLowerCase();
		const start = typed.length === 1 ? active + 1 : active;
		for (let k = 0; k < options.length; k++) {
			const i = (start + k) % options.length;
			if (options[i]!.label.toLocaleLowerCase().startsWith(q)) {
				if (open) move(i);
				else choose(i);
				return;
			}
		}
	}

	function onKeydown(e: KeyboardEvent) {
		if (e.key.length === 1 && e.key !== ' ' && !e.ctrlKey && !e.metaKey && !e.altKey) {
			typeahead(e.key);
			e.preventDefault();
			return;
		}
		if (!open) {
			if (['ArrowDown', 'ArrowUp', 'Enter', ' ', 'Home', 'End'].includes(e.key)) {
				e.preventDefault();
				show().then(() => {
					if (e.key === 'Home') move(0);
					else if (e.key === 'End') move(options.length - 1);
				});
			}
			return;
		}
		switch (e.key) {
			case 'ArrowDown':
				move(active + 1);
				break;
			case 'ArrowUp':
				move(active - 1);
				break;
			case 'Home':
				move(0);
				break;
			case 'End':
				move(options.length - 1);
				break;
			case 'PageDown':
				move(active + 8);
				break;
			case 'PageUp':
				move(active - 8);
				break;
			case 'Enter':
			case ' ':
				choose(active);
				break;
			case 'Escape':
				hide();
				break;
			case 'Tab':
				choose(active);
				return; // let focus move on
			default:
				return;
		}
		e.preventDefault();
	}
</script>

<svelte:window
	onpointerdown={(e) =>
		open && !trigger.contains(e.target as Node) && !list?.contains(e.target as Node) && hide()}
	onresize={() => open && position()}
	onscrollcapture={(e) => open && e.target !== list && position()}
/>

<div
	bind:this={trigger}
	{id}
	class="select {size}"
	role="combobox"
	tabindex="0"
	aria-label={labelledby ? undefined : label}
	aria-labelledby={labelledby}
	aria-haspopup="listbox"
	aria-expanded={open}
	aria-controls="{uid}-list"
	aria-activedescendant={open ? `${uid}-o${active}` : undefined}
	onclick={() => (open ? hide() : show())}
	onkeydown={onKeydown}
	onblur={(e) => !list?.contains(e.relatedTarget as Node) && hide()}
>
	<span class="value" lang={selected?.lang}>{selected?.label ?? ''}</span>
	<ChevronDown size={16} aria-hidden="true" class="chevron" />
</div>

{#if open}
	<ul
		bind:this={list}
		id="{uid}-list"
		class="list"
		class:up={place.up}
		role="listbox"
		popover="manual"
		aria-label={label}
		aria-labelledby={labelledby}
		tabindex="-1"
		style:top="{place.top}px"
		style:left="{place.left}px"
		style:min-width="{place.width}px"
		style:max-height="{place.max}px"
	>
		{#each options as o, i (o.value)}
			<!-- Keys are handled by the combobox, which keeps focus (aria-activedescendant). -->
			<!-- svelte-ignore a11y_click_events_have_key_events -->
			<li
				id="{uid}-o{i}"
				role="option"
				aria-selected={o.value === value}
				class:active={i === active}
				lang={o.lang}
				onpointermove={() => (active = i)}
				onpointerdown={(e) => e.preventDefault()}
				onclick={() => choose(i)}
			>
				<span>{o.label}</span>
				{#if o.value === value}<Check size={16} aria-hidden="true" />{/if}
			</li>
		{/each}
	</ul>
{/if}

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
		font-size: var(--text-sm);
		cursor: pointer;
		user-select: none;
		transition:
			border-color var(--duration-fast) var(--ease-standard),
			box-shadow var(--duration-fast) var(--ease-standard);
	}
	.select.sm {
		min-height: 2.25rem;
		min-width: 6rem;
		padding: 0 var(--space-2) 0 var(--space-3);
	}
	.select:hover {
		border-color: var(--color-text-muted);
	}
	.select:focus-visible {
		outline: 2px solid var(--color-focus);
		outline-offset: 1px;
	}
	.select[aria-expanded='true'] {
		border-color: var(--color-accent);
		box-shadow: 0 0 0 3px var(--color-accent-subtle);
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
	.select[aria-expanded='true'] :global(.chevron) {
		transform: rotate(180deg);
	}
	.list {
		position: fixed;
		inset: auto;
		z-index: 50;
		margin: 0;
		padding: var(--space-1);
		max-width: calc(100vw - 2 * var(--space-4));
		overflow-y: auto;
		list-style: none;
		background: var(--color-surface-raised);
		color: var(--color-text);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-md);
		box-shadow: var(--shadow-lg);
		animation: pop var(--duration-fast) var(--ease-emphasized);
		transform-origin: top left;
	}
	.list.up {
		transform: translateY(-100%);
		animation-name: pop-up;
		transform-origin: bottom left;
	}
	@keyframes pop {
		from {
			opacity: 0;
			transform: scale(0.97);
		}
	}
	@keyframes pop-up {
		from {
			opacity: 0;
			transform: translateY(-100%) scale(0.97);
		}
	}
	[role='option'] {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
		min-height: 2.5rem;
		padding: 0 var(--space-3);
		border-radius: var(--radius-sm);
		font-size: var(--text-sm);
		white-space: nowrap;
		cursor: pointer;
	}
	[role='option'].active {
		background: var(--color-surface-sunken);
	}
	[role='option'][aria-selected='true'] {
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
