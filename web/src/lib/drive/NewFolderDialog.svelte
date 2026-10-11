<script lang="ts">
	import { ClientResponseError } from 'pocketbase';
	import { m } from '#lib/paraglide/messages.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';
	import TextField from '#lib/ui/TextField.svelte';
	import { createFolder } from './api.js';
	import { isValidName } from './names.js';

	let { open = $bindable(false), parent }: { open?: boolean; parent: string } = $props();

	let name = $state('');
	let error = $state<string | null>(null);
	let busy = $state(false);

	$effect(() => {
		if (open) {
			name = '';
			error = null;
		}
	});

	async function submit(event: SubmitEvent) {
		event.preventDefault();
		const value = name.trim();
		if (!isValidName(value)) {
			error = value ? m.error_name_invalid() : m.error_field_required();
			return;
		}
		busy = true;
		try {
			await createFolder(parent, value);
			open = false;
		} catch (err) {
			// A unique-index violation on "name" means a sibling already uses it.
			error =
				err instanceof ClientResponseError && err.status === 400 && err.response?.data?.name
					? m.error_name_taken()
					: m.error_unexpected();
		} finally {
			busy = false;
		}
	}
</script>

<Dialog bind:open title={m.new_folder_title()}>
	<form onsubmit={submit} novalidate>
		<TextField
			label={m.folder_name_label()}
			bind:value={name}
			autofocus
			autocomplete="off"
			{error}
		/>
		{#if error === m.error_unexpected()}<Alert>{error}</Alert>{/if}
		<div class="actions">
			<Button variant="ghost" onclick={() => (open = false)}>{m.cancel_button()}</Button>
			<Button type="submit" loading={busy}>{m.create_button()}</Button>
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
