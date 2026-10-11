<script lang="ts">
	import { ClientResponseError } from 'pocketbase';
	import { m } from '#lib/paraglide/messages.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';
	import TextField from '#lib/ui/TextField.svelte';
	import { renameNode } from './api.js';
	import { isValidName } from './names.js';
	import type { DriveNode } from './types.js';

	let { node = $bindable(null) }: { node: DriveNode | null } = $props();

	let open = $state(false);
	let name = $state('');
	let error = $state<string | null>(null);
	let busy = $state(false);

	$effect(() => {
		if (node) {
			name = node.name;
			error = null;
			open = true;
		}
	});
	$effect(() => {
		if (!open) node = null;
	});

	async function submit(event: SubmitEvent) {
		event.preventDefault();
		if (!node) return;
		const value = name.trim();
		if (!isValidName(value)) {
			error = value ? m.error_name_invalid() : m.error_field_required();
			return;
		}
		if (value === node.name) {
			open = false;
			return;
		}
		busy = true;
		try {
			await renameNode(node.id, value);
			open = false;
		} catch (err) {
			error =
				err instanceof ClientResponseError && err.status === 400 && err.response?.data?.name
					? m.error_name_taken()
					: m.error_unexpected();
		} finally {
			busy = false;
		}
	}

	// Preselect the base name, not the extension (like desktop file managers).
	function selectBase(input: HTMLInputElement) {
		const dot = input.value.lastIndexOf('.');
		input.setSelectionRange(0, dot > 0 && node?.kind === 'file' ? dot : input.value.length);
	}
</script>

<Dialog bind:open title={m.rename_title()}>
	<form onsubmit={submit} novalidate>
		<TextField
			label={m.new_name_label()}
			bind:value={name}
			autofocus
			autocomplete="off"
			onfocus={(e) => selectBase(e.currentTarget)}
			{error}
		/>
		{#if error === m.error_unexpected()}<Alert>{error}</Alert>{/if}
		<div class="actions">
			<Button variant="ghost" onclick={() => (open = false)}>{m.cancel_button()}</Button>
			<Button type="submit" loading={busy}>{m.save_button()}</Button>
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
