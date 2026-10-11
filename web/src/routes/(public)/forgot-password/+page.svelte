<script lang="ts">
	import { resolve } from '$app/paths';
	import { authErrorKind } from '#lib/auth/errors.js';
	import { isEmail } from '#lib/auth/validation.js';
	import { m } from '#lib/paraglide/messages.js';
	import { pb } from '#lib/pb.js';
	import Alert from '#lib/ui/Alert.svelte';
	import AuthCard from '#lib/ui/AuthCard.svelte';
	import Button from '#lib/ui/Button.svelte';
	import TextField from '#lib/ui/TextField.svelte';

	let email = $state('');
	let submitted = $state(false);
	let busy = $state(false);
	let sent = $state(false);
	let failed = $state<string | null>(null);

	const emailError = $derived(
		!submitted
			? null
			: !email
				? m.error_field_required()
				: !isEmail(email)
					? m.error_email_invalid()
					: null
	);

	async function submit(event: SubmitEvent) {
		event.preventDefault();
		submitted = true;
		failed = null;
		if (emailError) return;
		busy = true;
		try {
			// The server answers the same whether or not the account exists.
			await pb.collection('users').requestPasswordReset(email.trim());
			sent = true;
		} catch (err) {
			const kind = authErrorKind(err);
			failed =
				kind === 'too-many'
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
	<title>{m.forgot_title()}</title>
</svelte:head>

<AuthCard title={m.forgot_title()}>
	{#if sent}
		<Alert tone="success">{m.forgot_sent()}</Alert>
	{:else}
		<p>{m.forgot_description()}</p>
		<form onsubmit={submit} novalidate>
			<TextField
				label={m.email_label()}
				type="email"
				bind:value={email}
				autocomplete="email"
				required
				error={emailError}
			/>
			{#if failed}<Alert>{failed}</Alert>{/if}
			<Button type="submit" loading={busy}>{m.send_link_button()}</Button>
		</form>
	{/if}
	<a href={resolve('/(public)/login')}>{m.back_to_sign_in()}</a>
</AuthCard>
