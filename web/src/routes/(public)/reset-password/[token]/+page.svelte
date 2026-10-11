<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { ClientResponseError } from 'pocketbase';
	import { authErrorKind } from '#lib/auth/errors.js';
	import { MIN_PASSWORD_LENGTH } from '#lib/auth/validation.js';
	import { m } from '#lib/paraglide/messages.js';
	import { pb } from '#lib/pb.js';
	import Alert from '#lib/ui/Alert.svelte';
	import AuthCard from '#lib/ui/AuthCard.svelte';
	import Button from '#lib/ui/Button.svelte';
	import TextField from '#lib/ui/TextField.svelte';

	let password = $state('');
	let confirm = $state('');
	let submitted = $state(false);
	let busy = $state(false);
	let done = $state(false);
	let failed = $state<string | null>(null);

	const passwordError = $derived(
		!submitted ? null : password.length < MIN_PASSWORD_LENGTH ? m.error_password_short() : null
	);
	const confirmError = $derived(
		submitted && confirm !== password ? m.error_password_mismatch() : null
	);

	async function submit(event: SubmitEvent) {
		event.preventDefault();
		submitted = true;
		failed = null;
		if (passwordError || confirmError) return;
		busy = true;
		try {
			await pb.collection('users').confirmPasswordReset(page.params.token ?? '', password, confirm);
			done = true;
		} catch (err) {
			const kind = authErrorKind(err);
			failed =
				err instanceof ClientResponseError && err.status === 400
					? m.error_reset_token()
					: kind === 'too-many'
						? m.error_too_many_attempts()
						: kind === 'network'
							? m.error_network()
							: m.error_unexpected();
		} finally {
			busy = false;
		}
	}
</script>

<svelte:head>
	<title>{m.reset_title()}</title>
</svelte:head>

<AuthCard title={m.reset_title()}>
	{#if done}
		<Alert tone="success">{m.reset_done()}</Alert>
		<a href={resolve('/(public)/login')}>{m.sign_in_button()}</a>
	{:else}
		<form onsubmit={submit} novalidate>
			<TextField
				label={m.new_password_label()}
				type="password"
				bind:value={password}
				autocomplete="new-password"
				minlength={MIN_PASSWORD_LENGTH}
				required
				hint={m.password_hint()}
				error={passwordError}
			/>
			<TextField
				label={m.confirm_password_label()}
				type="password"
				bind:value={confirm}
				autocomplete="new-password"
				required
				error={confirmError}
			/>
			{#if failed}<Alert>{failed}</Alert>{/if}
			<Button type="submit" loading={busy}>{m.reset_button()}</Button>
		</form>
		<a href={resolve('/(public)/forgot-password')}>{m.forgot_title()}</a>
	{/if}
</AuthCard>
