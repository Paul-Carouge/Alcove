<script lang="ts">
	import { Copy, Download, ShieldCheck, ShieldOff } from '@lucide/svelte';
	import {
		disableTotp,
		enableTotp,
		regenerateCodes,
		setupTotp,
		totpStatus,
		type TotpSetup,
		type TotpStatus
	} from '#lib/account/totp.js';
	import { PRODUCT_NAME } from '#lib/brand.js';
	import { m } from '#lib/paraglide/messages.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';
	import TextField from '#lib/ui/TextField.svelte';

	let status = $state<TotpStatus | null>(null);
	let error = $state<string | null>(null);

	// Enrolment
	let setup = $state<TotpSetup | null>(null);
	let setupOpen = $state(false);
	let enrollCode = $state('');
	let enrollError = $state<string | null>(null);
	let busy = $state(false);

	// Recovery codes shown once
	let codes = $state<string[] | null>(null);
	let codesOpen = $state(false);

	// Password + code confirmation (disable / regenerate)
	let confirmFor = $state<'disable' | 'regenerate' | null>(null);
	let confirmOpen = $state(false);
	let password = $state('');
	let confirmCode = $state('');
	let confirmError = $state<string | null>(null);

	async function refresh() {
		try {
			status = await totpStatus();
		} catch {
			error = m.error_load();
		}
	}

	$effect(() => {
		refresh();
	});

	async function startSetup() {
		error = null;
		try {
			setup = await setupTotp();
			enrollCode = '';
			enrollError = null;
			setupOpen = true;
		} catch {
			error = m.error_unexpected();
		}
	}

	async function activate(event: SubmitEvent) {
		event.preventDefault();
		if (!/^\d{6}$/.test(enrollCode.trim())) {
			enrollError = m.totp_invalid();
			return;
		}
		busy = true;
		try {
			const res = await enableTotp(enrollCode.trim());
			setupOpen = false;
			setup = null;
			codes = res.recoveryCodes;
			codesOpen = true;
			await refresh();
		} catch {
			enrollError = m.totp_invalid();
		} finally {
			busy = false;
		}
	}

	function askConfirm(action: 'disable' | 'regenerate') {
		confirmFor = action;
		password = '';
		confirmCode = '';
		confirmError = null;
		confirmOpen = true;
	}

	async function confirm(event: SubmitEvent) {
		event.preventDefault();
		if (!password || !confirmCode.trim()) {
			confirmError = m.error_field_required();
			return;
		}
		busy = true;
		try {
			if (confirmFor === 'disable') {
				await disableTotp(password, confirmCode.trim());
			} else {
				codes = (await regenerateCodes(password, confirmCode.trim())).recoveryCodes;
				codesOpen = true;
			}
			confirmOpen = false;
			await refresh();
		} catch {
			confirmError = m.security_wrong();
		} finally {
			busy = false;
		}
	}

	const codesText = $derived((codes ?? []).join('\n'));

	function downloadCodes() {
		const blob = new Blob([`${PRODUCT_NAME} recovery codes\n\n${codesText}\n`], {
			type: 'text/plain'
		});
		const a = document.createElement('a');
		a.href = URL.createObjectURL(blob);
		a.download = `${PRODUCT_NAME.toLowerCase()}-recovery-codes.txt`;
		a.click();
		URL.revokeObjectURL(a.href);
	}
</script>

<svelte:head>
	<title>{m.security_title()}</title>
</svelte:head>

<h1>{m.security_title()}</h1>

{#if error}<div class="err"><Alert>{error}</Alert></div>{/if}

<section class="card" aria-labelledby="twofa-title">
	<div class="icon" class:on={status?.enabled} aria-hidden="true">
		{#if status?.enabled}<ShieldCheck size={22} />{:else}<ShieldOff size={22} />{/if}
	</div>
	<div class="body">
		<h2 id="twofa-title">{m.security_2fa_title()}</h2>
		{#if status === null}
			<p class="muted">{m.loading()}</p>
		{:else if status.enabled}
			<p>{m.security_2fa_on()}</p>
			<p class="muted small">{m.security_recovery_left({ count: status.recoveryCodesLeft })}</p>
			<div class="actions">
				<Button variant="secondary" onclick={() => askConfirm('regenerate')}
					>{m.security_regenerate()}</Button
				>
				<Button variant="ghost" onclick={() => askConfirm('disable')}>{m.security_disable()}</Button
				>
			</div>
		{:else}
			<p class="muted">{m.security_2fa_off()}</p>
			<div class="actions">
				<Button onclick={startSetup}>{m.security_enable()}</Button>
			</div>
		{/if}
	</div>
</section>

<Dialog bind:open={setupOpen} title={m.security_2fa_title()}>
	{#if setup}
		<p class="step">{m.security_scan()}</p>
		<img class="qr" src={setup.qrCode} alt={m.security_qr_alt()} width="192" height="192" />
		<p class="step muted small">{m.security_manual()}</p>
		<code class="secret" aria-label={m.security_secret_label()}>{setup.secret}</code>
		<form onsubmit={activate} novalidate>
			<TextField
				label={m.security_confirm_code()}
				bind:value={enrollCode}
				inputmode="numeric"
				autocomplete="one-time-code"
				maxlength={6}
				error={enrollError}
			/>
			<div class="actions end">
				<Button variant="ghost" onclick={() => (setupOpen = false)}>{m.cancel_button()}</Button>
				<Button type="submit" loading={busy}>{m.security_activate()}</Button>
			</div>
		</form>
	{/if}
</Dialog>

<Dialog bind:open={codesOpen} title={m.security_codes_title()}>
	<p class="muted">{m.security_codes_body()}</p>
	<ol class="codes" aria-label={m.security_codes_title()}>
		{#each codes ?? [] as c (c)}<li><code>{c}</code></li>{/each}
	</ol>
	<div class="actions">
		<Button variant="secondary" onclick={() => navigator.clipboard.writeText(codesText)}>
			<Copy size={16} aria-hidden="true" />
			{m.security_copy_codes()}
		</Button>
		<Button variant="secondary" onclick={downloadCodes}>
			<Download size={16} aria-hidden="true" />
			{m.security_download_codes()}
		</Button>
	</div>
	<div class="actions end">
		<Button onclick={() => ((codesOpen = false), (codes = null))}>{m.security_codes_saved()}</Button
		>
	</div>
</Dialog>

<Dialog bind:open={confirmOpen} title={m.security_confirm_title()}>
	<p class="muted">{m.security_confirm_body()}</p>
	<form onsubmit={confirm} novalidate>
		<TextField
			label={m.password_label()}
			type="password"
			autocomplete="current-password"
			bind:value={password}
		/>
		<TextField
			label={m.security_code_or_recovery()}
			autocomplete="one-time-code"
			bind:value={confirmCode}
			error={confirmError}
		/>
		<div class="actions end">
			<Button variant="ghost" onclick={() => (confirmOpen = false)}>{m.cancel_button()}</Button>
			<Button
				type="submit"
				variant={confirmFor === 'disable' ? 'danger' : 'primary'}
				loading={busy}
			>
				{confirmFor === 'disable' ? m.security_disable() : m.security_regenerate()}
			</Button>
		</div>
	</form>
</Dialog>

<style>
	h1 {
		margin: 0 0 var(--space-6);
		padding-top: var(--space-3);
	}
	.err {
		margin-bottom: var(--space-4);
	}
	.card {
		display: flex;
		gap: var(--space-5);
		max-width: 44rem;
		padding: var(--space-6);
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-xl);
		box-shadow: var(--shadow-sm);
	}
	.icon {
		display: grid;
		place-items: center;
		flex: none;
		width: 3rem;
		height: 3.5rem;
		padding-top: var(--space-1);
		border-radius: var(--radius-full) var(--radius-full) var(--radius-md) var(--radius-md);
		background: var(--color-surface-sunken);
		color: var(--color-text-muted);
	}
	.icon.on {
		background: var(--color-accent-subtle);
		color: var(--color-success);
	}
	.body {
		display: grid;
		gap: var(--space-2);
	}
	h2 {
		font-size: var(--text-xl);
	}
	@media (max-width: 600px) {
		.card {
			flex-direction: column;
			padding: var(--space-5) var(--space-4);
		}
	}
	p {
		margin: 0;
	}
	.muted {
		color: var(--color-text-muted);
	}
	.small {
		font-size: var(--text-sm);
	}
	.actions {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
		margin-top: var(--space-2);
	}
	.end {
		justify-content: flex-end;
	}
	form {
		display: grid;
		gap: var(--space-4);
	}
	.qr {
		justify-self: center;
		padding: var(--space-2);
		border-radius: var(--radius-md);
		background: white;
		image-rendering: pixelated;
	}
	.secret {
		justify-self: center;
		padding: var(--space-2) var(--space-3);
		border-radius: var(--radius-sm);
		background: var(--color-surface-sunken);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		letter-spacing: 0.08em;
		overflow-wrap: anywhere;
		user-select: all;
	}
	.codes {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: var(--space-2) var(--space-5);
		margin: 0;
		padding: var(--space-4) var(--space-4) var(--space-4) var(--space-7);
		border-radius: var(--radius-md);
		background: var(--color-surface-sunken);
	}
	.codes code {
		font-family: var(--font-mono);
		font-size: var(--text-md);
		letter-spacing: 0.06em;
	}
</style>
