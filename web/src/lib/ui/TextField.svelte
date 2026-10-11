<script lang="ts">
	import type { HTMLInputAttributes } from 'svelte/elements';

	type Props = Omit<HTMLInputAttributes, 'value'> & {
		label: string;
		value?: string;
		error?: string | null;
		hint?: string | null;
	};

	let { label, value = $bindable(''), error = null, hint = null, id, ...rest }: Props = $props();

	const uid = $props.id();
	const inputId = $derived(id ?? `field-${uid}`);
	const describedBy = $derived(
		[error ? `${inputId}-error` : null, hint ? `${inputId}-hint` : null]
			.filter(Boolean)
			.join(' ') || undefined
	);
</script>

<div class="field">
	<label for={inputId}>{label}</label>
	<input
		{...rest}
		id={inputId}
		bind:value
		aria-invalid={error ? true : undefined}
		aria-describedby={describedBy}
	/>
	{#if hint && !error}<p class="hint" id="{inputId}-hint">{hint}</p>{/if}
	{#if error}<p class="error" id="{inputId}-error">{error}</p>{/if}
</div>

<style>
	.field {
		display: grid;
		gap: var(--space-1);
	}
	label {
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
	}
	input {
		font: inherit;
		min-height: 2.75rem;
		padding: var(--space-2) var(--space-3);
		color: var(--color-text);
		background: var(--color-surface);
		border: 1px solid var(--color-border-strong);
		border-radius: var(--radius-md);
		transition: border-color var(--duration-fast) var(--ease-standard);
	}
	input:focus-visible {
		outline: 2px solid var(--color-focus);
		outline-offset: 0;
		border-color: var(--color-focus);
	}
	input[aria-invalid='true'] {
		border-color: var(--color-danger);
	}
	.hint,
	.error {
		margin: 0;
		font-size: var(--text-sm);
	}
	.hint {
		color: var(--color-text-muted);
	}
	.error {
		color: var(--color-danger);
	}
</style>
