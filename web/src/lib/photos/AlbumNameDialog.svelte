<script lang="ts">
	import { m } from '#lib/paraglide/messages.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';
	import TextField from '#lib/ui/TextField.svelte';

	let {
		open = $bindable(false),
		title,
		submitLabel,
		initial = '',
		onsubmit
	}: {
		open?: boolean;
		title: string;
		submitLabel: string;
		initial?: string;
		onsubmit: (name: string) => Promise<void>;
	} = $props();

	let name = $state('');
	let error = $state<string | null>(null);
	let failed = $state(false);
	let busy = $state(false);

	$effect(() => {
		if (open) {
			name = initial;
			error = null;
			failed = false;
		}
	});

	async function submit(event: SubmitEvent) {
		event.preventDefault();
		const value = name.trim();
		if (!value) {
			error = m.error_field_required();
			return;
		}
		if (value.length > 100) {
			error = m.album_name_too_long();
			return;
		}
		busy = true;
		try {
			await onsubmit(value);
			open = false;
		} catch {
			failed = true;
		} finally {
			busy = false;
		}
	}
</script>

<Dialog bind:open {title}>
	<form onsubmit={submit} novalidate>
		<TextField
			label={m.album_name_label()}
			bind:value={name}
			autofocus
			autocomplete="off"
			maxlength={100}
			{error}
		/>
		{#if failed}<Alert>{m.error_unexpected()}</Alert>{/if}
		<div class="actions">
			<Button variant="ghost" onclick={() => (open = false)}>{m.cancel_button()}</Button>
			<Button type="submit" loading={busy}>{submitLabel}</Button>
		</div>
	</form>
</Dialog>

<style>
	form {
		display: grid;
		gap: var(--space-4);
	}
	.actions {
		display: flex;
		justify-content: flex-end;
		gap: var(--space-2);
	}
</style>
