<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { Check, HardDrive, Mail, ShieldCheck } from '@lucide/svelte';
	import { MIN_PASSWORD_LENGTH, isEmail } from '#lib/auth/validation.js';
	import { m } from '#lib/paraglide/messages.js';
	import { pb } from '#lib/pb.js';
	import { serverStatus } from '#lib/server-status/store.svelte.js';
	import {
		completeSetup,
		SetupError,
		setupStatus,
		testSmtp,
		type SetupStatus,
		type SmtpSettings
	} from '#lib/setup/api.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import TextField from '#lib/ui/TextField.svelte';

	const appName = $derived(
		serverStatus.current?.kind === 'connected' ? serverStatus.current.health.name : 'Alcove'
	);

	type Step = 0 | 1 | 2 | 3;
	let step = $state<Step>(0);
	const steps = [m.setup_step_welcome, m.setup_step_admin, m.setup_step_email, m.setup_step_finish];

	// Step 0: token
	let token = $state(page.url.searchParams.get('token') ?? '');
	let tokenError = $state<string | null>(null);
	let status = $state<SetupStatus | null>(null);
	let done = $state(false);

	// Step 1: admin
	let name = $state('');
	let email = $state('');
	let password = $state('');
	let confirm = $state('');
	let adminSubmitted = $state(false);
	const emailError = $derived(
		!adminSubmitted
			? null
			: !email
				? m.error_field_required()
				: !isEmail(email)
					? m.error_email_invalid()
					: null
	);
	const passwordError = $derived(
		adminSubmitted && password.length < MIN_PASSWORD_LENGTH ? m.error_password_short() : null
	);
	const confirmError = $derived(
		adminSubmitted && confirm !== password ? m.error_password_mismatch() : null
	);

	// Step 2: SMTP (optional)
	let withSmtp = $state(false);
	let smtp = $state<SmtpSettings>({
		host: '',
		port: 587,
		username: '',
		password: '',
		tls: false,
		senderAddress: '',
		senderName: ''
	});
	let smtpError = $state<string | null>(null);
	let smtpOk = $state(false);

	let busy = $state(false);
	let error = $state<string | null>(null);

	// Done already (or not needed): go to sign-in.
	$effect(() => {
		if (
			serverStatus.current?.kind === 'connected' &&
			!serverStatus.current.health.setupRequired &&
			!busy
		)
			done = true;
	});

	// The token from the link is checked right away.
	$effect(() => {
		if (token && step === 0 && !status) checkToken();
	});

	async function checkToken(event?: SubmitEvent) {
		event?.preventDefault();
		tokenError = null;
		if (!token.trim()) {
			tokenError = m.error_field_required();
			return;
		}
		busy = true;
		try {
			status = await setupStatus(token.trim());
			step = 1;
		} catch (err) {
			if (err instanceof SetupError && err.status === 409) done = true;
			else tokenError = m.setup_token_invalid();
		} finally {
			busy = false;
		}
	}

	function adminNext(event: SubmitEvent) {
		event.preventDefault();
		adminSubmitted = true;
		if (emailError || passwordError || confirmError) return;
		if (!smtp.senderAddress) smtp.senderAddress = email.trim();
		step = 2;
	}

	const smtpValid = () => !!smtp.host && smtp.port > 0 && isEmail(smtp.senderAddress);

	async function sendTest() {
		smtpError = null;
		smtpOk = false;
		if (!smtpValid()) {
			smtpError = m.error_field_required();
			return;
		}
		busy = true;
		try {
			await testSmtp(token.trim(), smtp, email.trim());
			smtpOk = true;
		} catch (err) {
			smtpError = err instanceof SetupError && err.message ? err.message : m.error_unexpected();
		} finally {
			busy = false;
		}
	}

	function emailNext(event: SubmitEvent) {
		event.preventDefault();
		if (withSmtp && !smtpValid()) {
			smtpError = m.error_field_required();
			return;
		}
		step = 3;
	}

	async function finish() {
		busy = true;
		error = null;
		try {
			await completeSetup(
				token.trim(),
				{ name: name.trim(), email: email.trim(), password },
				withSmtp ? smtp : undefined
			);
			await pb.collection('users').authWithPassword(email.trim(), password);
			await serverStatus.check();
			await goto(resolve('/(app)'), { replace: true });
		} catch (err) {
			error =
				err instanceof SetupError && err.status === 409 ? m.setup_already_done() : m.setup_failed();
		} finally {
			busy = false;
		}
	}
</script>

<svelte:head>
	<title>{m.setup_title({ name: appName })}</title>
	<meta name="robots" content="noindex" />
</svelte:head>

{#if done}
	<section class="card">
		<Alert tone="info">{m.setup_already_done()}</Alert>
		<a href={resolve('/(public)/login')}>{m.sign_in_button()}</a>
	</section>
{:else}
	<ol class="stepper" aria-label={m.setup_steps()}>
		{#each steps as label, i (i)}
			<li
				class:current={i === step}
				class:past={i < step}
				aria-current={i === step ? 'step' : undefined}
			>
				<span class="dot"
					>{#if i < step}<Check size={14} aria-hidden="true" />{:else}{i + 1}{/if}</span
				>
				<span class="label">{label()}</span>
			</li>
		{/each}
	</ol>

	<section class="card" aria-labelledby="step-title">
		{#if step === 0}
			<h1 id="step-title">{m.setup_welcome_title({ name: appName })}</h1>
			<p class="muted">{m.setup_welcome_body()}</p>
			<form onsubmit={checkToken} novalidate>
				<TextField
					label={m.setup_token_label()}
					bind:value={token}
					autocomplete="off"
					hint={m.setup_token_hint()}
					error={tokenError}
				/>
				<div class="actions">
					<Button type="submit" loading={busy}>{m.setup_continue()}</Button>
				</div>
			</form>
		{:else if step === 1}
			<h1 id="step-title">{m.setup_admin_title()}</h1>
			<p class="muted">{m.setup_admin_body()}</p>
			<form onsubmit={adminNext} novalidate>
				<TextField label={m.name_label()} bind:value={name} autocomplete="name" />
				<TextField
					label={m.email_label()}
					type="email"
					bind:value={email}
					autocomplete="username"
					error={emailError}
				/>
				<TextField
					label={m.password_label()}
					type="password"
					bind:value={password}
					autocomplete="new-password"
					hint={m.password_hint()}
					error={passwordError}
				/>
				<TextField
					label={m.confirm_password_label()}
					type="password"
					bind:value={confirm}
					autocomplete="new-password"
					error={confirmError}
				/>
				<div class="actions">
					<Button variant="ghost" onclick={() => (step = 0)}>{m.setup_back()}</Button>
					<Button type="submit">{m.setup_continue()}</Button>
				</div>
			</form>
		{:else if step === 2}
			<h1 id="step-title">{m.setup_email_title()}</h1>
			<p class="muted">{m.setup_email_body()}</p>
			<form onsubmit={emailNext} novalidate>
				<label class="toggle">
					<input type="checkbox" bind:checked={withSmtp} />
					{m.setup_email_toggle()}
				</label>
				{#if withSmtp}
					<div class="row">
						<TextField
							label={m.smtp_host()}
							bind:value={smtp.host}
							autocomplete="off"
							placeholder="smtp.example.com"
						/>
						<div class="port">
							<TextField
								label={m.smtp_port()}
								type="number"
								value={String(smtp.port)}
								oninput={(e) => (smtp.port = Number(e.currentTarget.value))}
							/>
						</div>
					</div>
					<TextField label={m.smtp_username()} bind:value={smtp.username} autocomplete="off" />
					<TextField
						label={m.smtp_password()}
						type="password"
						bind:value={smtp.password}
						autocomplete="off"
					/>
					<label class="toggle">
						<input type="checkbox" bind:checked={smtp.tls} />
						{m.smtp_tls()}
					</label>
					<TextField label={m.smtp_sender()} type="email" bind:value={smtp.senderAddress} />
					<TextField
						label={m.smtp_sender_name()}
						bind:value={smtp.senderName}
						placeholder={appName}
					/>
					{#if smtpError}<Alert>{smtpError}</Alert>{/if}
					{#if smtpOk}<Alert tone="success">{m.smtp_test_ok()}</Alert>{/if}
					<div>
						<Button variant="secondary" onclick={sendTest} loading={busy}
							>{m.smtp_test({ email: email.trim() })}</Button
						>
					</div>
				{/if}
				<div class="actions">
					<Button variant="ghost" onclick={() => (step = 1)}>{m.setup_back()}</Button>
					<Button type="submit">{m.setup_continue()}</Button>
				</div>
			</form>
		{:else}
			<h1 id="step-title">{m.setup_finish_title()}</h1>
			<ul class="summary">
				<li>
					<span class="ic" aria-hidden="true"><ShieldCheck size={18} /></span>
					<span><strong>{m.setup_summary_admin()}</strong> · {email.trim()}</span>
				</li>
				<li>
					<span class="ic" aria-hidden="true"><Mail size={18} /></span>
					<span
						><strong>{m.setup_summary_email()}</strong> · {withSmtp
							? m.setup_email_configured()
							: m.setup_email_skipped()}</span
					>
				</li>
				{#if status}
					<li class:bad={!status.storage.writable}>
						<span class="ic" aria-hidden="true"><HardDrive size={18} /></span>
						<span>
							<strong>{m.setup_storage()}</strong> ·
							{status.storage.type === 's3' ? m.setup_storage_s3() : m.setup_storage_local()},
							{status.storage.writable
								? m.setup_storage_ok()
								: m.setup_storage_fail({ error: status.storage.error ?? '' })}
						</span>
					</li>
				{/if}
			</ul>
			{#if error}<Alert>{error}</Alert>{/if}
			<div class="actions">
				<Button variant="ghost" onclick={() => (step = 2)}>{m.setup_back()}</Button>
				<Button
					onclick={finish}
					loading={busy}
					disabled={status ? !status.storage.writable : false}
				>
					{m.setup_finish()}
				</Button>
			</div>
		{/if}
	</section>
{/if}

<style>
	.stepper {
		display: flex;
		justify-content: space-between;
		gap: var(--space-2);
		margin: var(--space-4) 0 var(--space-5);
		padding: 0;
		list-style: none;
		counter-reset: step;
	}
	.stepper li {
		flex: 1;
		display: grid;
		justify-items: center;
		gap: var(--space-1);
		position: relative;
		font-size: var(--text-xs);
		color: var(--color-text-muted);
	}
	.stepper li:not(:last-child)::after {
		content: '';
		position: absolute;
		top: 0.875rem;
		left: calc(50% + 1.1rem);
		right: calc(-50% + 1.1rem);
		height: 2px;
		background: var(--color-border);
	}
	.stepper li.past:not(:last-child)::after {
		background: var(--color-accent);
	}
	.dot {
		display: grid;
		place-items: center;
		width: 1.75rem;
		height: 1.75rem;
		border-radius: var(--radius-full);
		border: 2px solid var(--color-border-strong);
		background: var(--color-surface);
		font-weight: var(--weight-semibold);
	}
	.current .dot {
		border-color: var(--color-accent);
		color: var(--color-accent);
	}
	.past .dot {
		border-color: var(--color-accent);
		background: var(--color-accent);
		color: var(--color-accent-contrast);
	}
	.current .label {
		color: var(--color-text);
		font-weight: var(--weight-medium);
	}
	.card {
		display: grid;
		gap: var(--space-4);
		padding: var(--space-6);
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		box-shadow: var(--shadow-md);
	}
	h1 {
		font-size: var(--text-2xl);
		letter-spacing: -0.02em;
	}
	p {
		margin: 0;
	}
	.muted {
		color: var(--color-text-muted);
	}
	form {
		display: grid;
		gap: var(--space-4);
	}
	.actions {
		display: flex;
		justify-content: flex-end;
		gap: var(--space-2);
	}
	.toggle {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		min-height: 2.75rem;
		cursor: pointer;
	}
	.toggle input {
		width: 1.125rem;
		height: 1.125rem;
		accent-color: var(--color-accent);
	}
	.row {
		display: grid;
		grid-template-columns: 1fr 7rem;
		gap: var(--space-3);
	}
	.summary {
		display: grid;
		gap: var(--space-2);
		margin: 0;
		padding: 0;
		list-style: none;
	}
	.summary li {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-3);
		border-radius: var(--radius-md);
		background: var(--color-surface-sunken);
	}
	.summary li.bad {
		color: var(--color-danger);
	}
	.ic {
		display: grid;
		place-items: center;
		color: var(--color-accent);
	}
	@media (max-width: 600px) {
		.stepper .label {
			display: none;
		}
	}
</style>
