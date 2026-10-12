<script lang="ts">
	import { Check, Copy, Lock, Trash2 } from '@lucide/svelte';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import { formatDate, formatDateTime } from '#lib/drive/format.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';
	import TextField from '#lib/ui/TextField.svelte';
	import {
		createShare,
		expiryFromPreset,
		revokeShare,
		shareUrl,
		sharesFor,
		type ShareRecord,
		type ShareTarget
	} from './api.js';

	let { target = $bindable(null) }: { target: ShareTarget | null } = $props();

	type Preset = 'never' | '1d' | '7d' | '30d';
	let open = $state(false);
	let existing = $state<ShareRecord[]>([]);
	let preset = $state<Preset>('7d');
	let protect = $state(false);
	let password = $state('');
	let passwordError = $state<string | null>(null);
	let busy = $state(false);
	let error = $state<string | null>(null);
	let created = $state<string | null>(null);
	let copied = $state(false);

	const locale = getLocale();
	const presets: { value: Preset; label: () => string }[] = [
		{ value: 'never', label: m.expiry_never },
		{ value: '1d', label: m.expiry_1d },
		{ value: '7d', label: m.expiry_7d },
		{ value: '30d', label: m.expiry_30d }
	];

	$effect(() => {
		if (!target) return;
		open = true;
		created = null;
		error = null;
		protect = false;
		password = '';
		passwordError = null;
		copied = false;
		sharesFor(target)
			.then((list) => (existing = list))
			.catch(() => (existing = []));
	});
	$effect(() => {
		if (!open) target = null;
	});

	async function submit(event: SubmitEvent) {
		event.preventDefault();
		if (!target) return;
		passwordError = protect && password.length < 4 ? m.share_password_hint() : null;
		if (passwordError) return;
		busy = true;
		error = null;
		try {
			const res = await createShare(target, {
				expiresAt: expiryFromPreset(preset),
				password: protect ? password : undefined
			});
			created = shareUrl(res.token);
			existing = await sharesFor(target);
		} catch {
			error = m.error_unexpected();
		} finally {
			busy = false;
		}
	}

	async function copy() {
		if (!created) return;
		await navigator.clipboard.writeText(created);
		copied = true;
	}

	async function revoke(share: ShareRecord) {
		await revokeShare(share.id).catch(() => (error = m.error_unexpected()));
		existing = existing.filter((s) => s.id !== share.id);
	}
</script>

<Dialog bind:open title={m.share_title({ name: target?.name ?? '' })}>
	{#if created}
		<div class="created">
			<label class="label" for="share-link">{m.share_link_label()}</label>
			<div class="link-row">
				<input id="share-link" readonly value={created} onfocus={(e) => e.currentTarget.select()} />
				<Button onclick={copy}>
					{#if copied}<Check size={18} aria-hidden="true" />{:else}<Copy
							size={18}
							aria-hidden="true"
						/>{/if}
					{copied ? m.share_copied() : m.share_copy()}
				</Button>
			</div>
			<p class="note" role="status">{m.share_once_note()}</p>
		</div>
		<div class="actions">
			<Button variant="secondary" onclick={() => (open = false)}>{m.share_done()}</Button>
		</div>
	{:else}
		<form onsubmit={submit} novalidate>
			{#if target?.album}<p class="note">{m.share_album_note()}</p>{/if}
			<fieldset>
				<legend class="label">{m.share_expiry_label()}</legend>
				<div class="chips">
					{#each presets as p (p.value)}
						<label class="chip" class:on={preset === p.value}>
							<input type="radio" name="expiry" value={p.value} bind:group={preset} />
							{p.label()}
						</label>
					{/each}
				</div>
			</fieldset>
			<label class="toggle">
				<input type="checkbox" bind:checked={protect} />
				{m.share_password_toggle()}
			</label>
			{#if protect}
				<TextField
					label={m.share_password_label()}
					type="password"
					autocomplete="new-password"
					bind:value={password}
					hint={m.share_password_hint()}
					error={passwordError}
				/>
			{/if}
			{#if error}<Alert>{error}</Alert>{/if}
			<div class="actions">
				<Button variant="ghost" onclick={() => (open = false)}>{m.cancel_button()}</Button>
				<Button type="submit" loading={busy}>{m.share_create()}</Button>
			</div>
		</form>
	{/if}

	<section class="existing" aria-labelledby="existing-title">
		<h3 id="existing-title" class="label">{m.share_existing()}</h3>
		{#if existing.length === 0}
			<p class="muted">{m.share_none()}</p>
		{:else}
			<ul>
				{#each existing as share (share.id)}
					<li>
						<div class="info">
							<span>{m.share_created({ date: formatDateTime(share.created, locale) })}</span>
							<span class="muted small">
								{share.expires_at
									? m.share_expires({ date: formatDate(share.expires_at, locale) })
									: m.share_no_expiry()}
								{#if share.has_password}· <Lock size={12} aria-hidden="true" />
									{m.share_protected()}{/if}
							</span>
						</div>
						<button
							class="icon-btn"
							aria-label={m.share_revoke_label({ date: formatDateTime(share.created, locale) })}
							title={m.share_revoke()}
							onclick={() => revoke(share)}
						>
							<Trash2 size={16} aria-hidden="true" />
						</button>
					</li>
				{/each}
			</ul>
		{/if}
	</section>
</Dialog>

<style>
	form,
	.created {
		display: grid;
		gap: var(--space-4);
	}
	fieldset {
		border: 0;
		margin: 0;
		padding: 0;
		display: grid;
		gap: var(--space-2);
	}
	.label {
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
	}
	.chips {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
	}
	.chip {
		display: inline-flex;
		align-items: center;
		min-height: 2.5rem;
		padding: 0 var(--space-3);
		border: 1px solid var(--color-border-strong);
		border-radius: var(--radius-full);
		font-size: var(--text-sm);
		cursor: pointer;
	}
	.chip input {
		position: absolute;
		opacity: 0;
		pointer-events: none;
	}
	.chip:has(input:focus-visible) {
		outline: 2px solid var(--color-focus);
		outline-offset: 2px;
	}
	.chip.on {
		border-color: var(--color-accent);
		background: var(--color-accent-subtle);
		color: var(--color-accent);
		font-weight: var(--weight-medium);
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
	.link-row {
		display: flex;
		gap: var(--space-2);
	}
	.link-row input {
		flex: 1;
		min-width: 0;
		font: inherit;
		font-size: var(--text-sm);
		padding: 0 var(--space-3);
		min-height: 2.75rem;
		color: var(--color-text);
		background: var(--color-surface-sunken);
		border: 1px solid var(--color-border-strong);
		border-radius: var(--radius-md);
	}
	.note {
		margin: 0;
		font-size: var(--text-sm);
		color: var(--color-warning);
	}
	.actions {
		display: flex;
		justify-content: flex-end;
		gap: var(--space-2);
	}
	.existing {
		display: grid;
		gap: var(--space-2);
		padding-top: var(--space-4);
		border-top: 1px solid var(--color-border);
	}
	.existing h3 {
		margin: 0;
	}
	ul {
		list-style: none;
		margin: 0;
		padding: 0;
		display: grid;
		gap: var(--space-1);
	}
	li {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
	}
	.info {
		display: grid;
		font-size: var(--text-sm);
	}
	.muted {
		margin: 0;
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.small {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
		font-size: var(--text-xs);
	}
	.icon-btn {
		display: grid;
		place-items: center;
		width: 2.75rem;
		height: 2.75rem;
		border: 0;
		border-radius: var(--radius-md);
		background: transparent;
		color: var(--color-danger);
		cursor: pointer;
	}
	.icon-btn:hover {
		background: var(--color-surface-sunken);
	}
</style>
