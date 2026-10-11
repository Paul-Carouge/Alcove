<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { authErrorKind, mfaIdFrom, type AuthErrorKind } from '#lib/auth/errors.js';
	import { safeNext } from '#lib/auth/redirect.js';
	import { isEmail } from '#lib/auth/validation.js';
	import { m } from '#lib/paraglide/messages.js';
	import { pb } from '#lib/pb.js';
	import Alert from '#lib/ui/Alert.svelte';
	import AuthCard from '#lib/ui/AuthCard.svelte';
	import Button from '#lib/ui/Button.svelte';
	import TextField from '#lib/ui/TextField.svelte';

	let email = $state('');
	let password = $state('');
	let otp = $state('');
	let submitted = $state(false);
	let busy = $state(false);
	let error = $state<AuthErrorKind | 'otp-invalid' | null>(null);
	/** Set when the server asks for a second factor. */
	let mfa = $state<{ mfaId: string; otpId: string } | null>(null);

	const emailError = $derived(
		!submitted
			? null
			: !email
				? m.error_field_required()
				: !isEmail(email)
					? m.error_email_invalid()
					: null
	);
	const passwordError = $derived(submitted && !password ? m.error_field_required() : null);

	const errorText = (kind: NonNullable<typeof error>) =>
		({
			'bad-credentials': m.error_bad_credentials(),
			'too-many': m.error_too_many_attempts(),
			network: m.error_network(),
			unexpected: m.error_unexpected(),
			'otp-invalid': m.error_otp_invalid()
		})[kind];

	async function done() {
		// `next` is a runtime path (validated by safeNext), not a static route id.
		// eslint-disable-next-line svelte/no-navigation-without-resolve
		await goto(safeNext(page.url.searchParams.get('next')), { replaceState: true });
	}

	async function signIn(event: SubmitEvent) {
		event.preventDefault();
		submitted = true;
		error = null;
		if (emailError || passwordError) return;
		busy = true;
		try {
			await pb.collection('users').authWithPassword(email.trim(), password);
			await done();
		} catch (err) {
			const mfaId = mfaIdFrom(err);
			if (mfaId) {
				try {
					const { otpId } = await pb.collection('users').requestOTP(email.trim());
					mfa = { mfaId, otpId };
				} catch (otpErr) {
					error = authErrorKind(otpErr);
				}
			} else {
				error = authErrorKind(err);
			}
		} finally {
			busy = false;
		}
	}

	async function verifyOtp(event: SubmitEvent) {
		event.preventDefault();
		if (!mfa || !otp.trim()) return;
		busy = true;
		error = null;
		try {
			await pb.collection('users').authWithOTP(mfa.otpId, otp.trim(), { mfaId: mfa.mfaId });
			await done();
		} catch (err) {
			const kind = authErrorKind(err);
			error = kind === 'bad-credentials' ? 'otp-invalid' : kind;
		} finally {
			busy = false;
		}
	}
</script>

<svelte:head>
	<title>{mfa ? m.mfa_title() : m.sign_in_title()}</title>
</svelte:head>

{#if mfa}
	<AuthCard title={m.mfa_title()}>
		<p>{m.mfa_description({ email })}</p>
		<form onsubmit={verifyOtp} novalidate>
			<TextField
				label={m.otp_label()}
				bind:value={otp}
				inputmode="numeric"
				autocomplete="one-time-code"
				required
			/>
			{#if error}<Alert>{errorText(error)}</Alert>{/if}
			<Button type="submit" loading={busy}>{m.verify_button()}</Button>
		</form>
		<Button variant="ghost" onclick={() => ((mfa = null), (otp = ''), (error = null))}>
			{m.back_to_sign_in()}
		</Button>
	</AuthCard>
{:else}
	<AuthCard title={m.sign_in_title()}>
		<form onsubmit={signIn} novalidate>
			<TextField
				label={m.email_label()}
				type="email"
				bind:value={email}
				autocomplete="username"
				required
				error={emailError}
			/>
			<TextField
				label={m.password_label()}
				type="password"
				bind:value={password}
				autocomplete="current-password"
				required
				error={passwordError}
			/>
			{#if error}<Alert>{errorText(error)}</Alert>{/if}
			<Button type="submit" loading={busy}>{m.sign_in_button()}</Button>
		</form>
		<a href={resolve('/(public)/forgot-password')}>{m.forgot_password_link()}</a>
	</AuthCard>
{/if}
