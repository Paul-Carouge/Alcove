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
		min-width: 0;
		display: grid;
		gap: var(--space-2);
	}
	label {
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		color: var(--color-text);
	}
	input {
		width: 100%;
		min-width: 0;
		font: inherit;
		min-height: 2.75rem;
		padding: var(--space-2) var(--space-3);
		color: var(--color-text);
		background: var(--color-surface);
		border: 1px solid var(--color-border-strong);
		border-radius: var(--radius-md);
		box-shadow: inset 0 1px 0 0 color-mix(in srgb, var(--color-text) 3%, transparent);
		transition:
			border-color var(--duration-fast) var(--ease-standard),
			box-shadow var(--duration-fast) var(--ease-standard);
	}
	input::placeholder {
		color: var(--color-text-muted);
	}
	input:hover:not(:focus-visible) {
		border-color: var(--color-text-muted);
	}
	input:focus-visible {
		outline: none;
		border-color: var(--color-focus);
		box-shadow:
			0 0 0 1px var(--color-focus),
			0 0 0 4px var(--color-accent-subtle);
	}
	input[aria-invalid='true'] {
		border-color: var(--color-danger);
	}
	input[aria-invalid='true']:focus-visible {
		box-shadow: 0 0 0 1px var(--color-danger);
	}
	input:disabled {
		background: var(--color-surface-sunken);
		color: var(--color-text-muted);
		cursor: not-allowed;
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
