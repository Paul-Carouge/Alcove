<script lang="ts">
	import { Check, Copy, KeyRound, Pencil, Shield, Trash2, UserPlus } from '@lucide/svelte';
	import {
		AdminError,
		createUser,
		deleteUser,
		generatePassword,
		GB,
		listUsers,
		updateUser,
		type AdminUser
	} from '#lib/admin/api.js';
	import { session } from '#lib/auth/session.svelte.js';
	import { formatSize } from '#lib/drive/format.js';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import ActionsMenu from '#lib/ui/ActionsMenu.svelte';
	import Alert from '#lib/ui/Alert.svelte';
	import Avatar from '#lib/ui/Avatar.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';
	import TextField from '#lib/ui/TextField.svelte';

	const locale = getLocale();
	let users = $state<AdminUser[] | null>(null);
	let failed = $state(false);
	let status = $state('');

	// Create / edit dialog.
	let editing = $state<AdminUser | 'new' | null>(null);
	let form = $state({ email: '', name: '', quotaGB: '', admin: false });
	let formError = $state('');
	let saving = $state(false);
	/** The password just set, shown once to hand over. */
	let issued = $state<{ email: string; password: string } | null>(null);
	let copied = $state(false);

	let deleting = $state<AdminUser | null>(null);
	let confirmEmail = $state('');

	async function load() {
		try {
			users = await listUsers();
			failed = false;
		} catch {
			failed = true;
		}
	}

	$effect(() => {
		if (session.isAdmin) load();
	});

	function openCreate() {
		form = { email: '', name: '', quotaGB: '', admin: false };
		formError = '';
		editing = 'new';
	}

	function openEdit(u: AdminUser) {
		form = {
			email: u.email,
			name: u.name,
			quotaGB: u.quotaBytes ? String(Math.round((u.quotaBytes / GB) * 10) / 10) : '',
			admin: u.admin
		};
		formError = '';
		editing = u;
	}

	const quotaBytes = () => {
		const v = Number(form.quotaGB.replace(',', '.'));
		return form.quotaGB.trim() === '' || !Number.isFinite(v) || v <= 0 ? 0 : Math.round(v * GB);
	};

	async function save(event: SubmitEvent) {
		event.preventDefault();
		saving = true;
		formError = '';
		try {
			if (editing === 'new') {
				const password = generatePassword();
				const u = await createUser({
					email: form.email.trim(),
					name: form.name.trim(),
					quotaBytes: quotaBytes(),
					admin: form.admin,
					password
				});
				issued = { email: u.email, password };
				status = m.users_created({ email: u.email });
			} else if (editing) {
				await updateUser(editing.id, {
					name: form.name.trim(),
					quotaBytes: quotaBytes(),
					admin: form.admin
				});
				status = m.users_saved({ email: editing.email });
			}
			editing = null;
			copied = false;
			await load();
		} catch (err) {
			formError = err instanceof AdminError && err.message ? err.message : m.error_unexpected();
		} finally {
			saving = false;
		}
	}

	async function resetPassword(u: AdminUser) {
		const password = generatePassword();
		try {
			await updateUser(u.id, { password });
			issued = { email: u.email, password };
			copied = false;
		} catch (err) {
			status = err instanceof AdminError && err.message ? err.message : m.error_unexpected();
		}
	}

	async function remove() {
		if (!deleting) return;
		try {
			await deleteUser(deleting.id);
			status = m.users_deleted({ email: deleting.email });
			deleting = null;
			await load();
		} catch (err) {
			status = err instanceof AdminError && err.message ? err.message : m.error_unexpected();
			deleting = null;
		}
	}

	async function copy() {
		if (!issued) return;
		await navigator.clipboard.writeText(issued.password);
		copied = true;
	}

	const usage = (u: AdminUser) =>
		u.quotaBytes
			? m.users_usage_of({
					used: formatSize(u.usedBytes, locale),
					quota: formatSize(u.quotaBytes, locale)
				})
			: m.users_usage({ used: formatSize(u.usedBytes, locale) });
	const since = (iso: string) =>
		new Intl.DateTimeFormat(locale, { dateStyle: 'medium' }).format(
			new Date(iso.replace(' ', 'T'))
		);
	const ratio = (u: AdminUser) => (u.quotaBytes ? Math.min(1, u.usedBytes / u.quotaBytes) : 0);
</script>

<svelte:head>
	<title>{m.users_title()}</title>
</svelte:head>

<div class="head">
	<h1>{m.users_title()}</h1>
	{#if session.isAdmin}
		<Button onclick={openCreate}><UserPlus size={16} aria-hidden="true" />{m.users_new()}</Button>
	{/if}
</div>

<p class="status" role="status">{status}</p>

{#if !session.isAdmin}
	<Alert tone="info">{m.admin_only()}</Alert>
{:else if failed}
	<Alert>{m.error_load()}</Alert>
{:else if users === null}
	<p class="muted">{m.loading()}</p>
{:else}
	<ul class="list">
		{#each users as u (u.id)}
			{@const me = u.id === session.user?.id}
			<li class="row">
				<Avatar name={u.name} email={u.email} size={40} />
				<div class="who">
					<span class="name">
						{u.name || u.email}
						{#if u.admin}<span class="badge"
								><Shield size={12} aria-hidden="true" />{m.users_admin()}</span
							>{/if}
						{#if me}<span class="badge subtle">{m.users_you()}</span>{/if}
					</span>
					<span class="muted"
						>{u.email} · {m.users_since({ date: since(u.created) })}{#if u.twoFactor}
							· {m.users_two_factor()}{/if}</span
					>
				</div>
				<div class="usage">
					<span class="muted">{usage(u)}</span>
					{#if u.quotaBytes}
						<span class="bar" role="presentation"
							><span style:width="{ratio(u) * 100}%"></span></span
						>
					{/if}
				</div>
				<ActionsMenu
					label={m.users_actions({ name: u.name || u.email })}
					actions={[
						{ label: m.users_edit(), icon: Pencil, onselect: () => openEdit(u) },
						{ label: m.users_reset_password(), icon: KeyRound, onselect: () => resetPassword(u) },
						...(me
							? []
							: [
									{
										label: m.users_delete(),
										icon: Trash2,
										danger: true,
										onselect: () => {
											confirmEmail = '';
											deleting = u;
										}
									}
								])
					]}
				/>
			</li>
		{/each}
	</ul>
{/if}

<Dialog
	open={editing !== null}
	title={editing === 'new' ? m.users_new() : m.users_edit()}
	onclose={() => (editing = null)}
>
	<form onsubmit={save} novalidate class="form">
		<TextField
			label={m.email_label()}
			type="email"
			bind:value={form.email}
			disabled={editing !== 'new'}
			autocomplete="off"
		/>
		<TextField label={m.users_name()} bind:value={form.name} autocomplete="off" />
		<TextField
			label={m.users_quota()}
			bind:value={form.quotaGB}
			inputmode="decimal"
			hint={m.users_quota_hint()}
		/>
		<label class="check">
			<input
				type="checkbox"
				bind:checked={form.admin}
				disabled={editing !== 'new' && editing?.id === session.user?.id}
			/>
			{m.users_admin_role()}
		</label>
		{#if editing === 'new'}<p class="muted small">{m.users_new_note()}</p>{/if}
		{#if formError}<Alert>{formError}</Alert>{/if}
		<div class="actions">
			<Button variant="ghost" onclick={() => (editing = null)}>{m.cancel_button()}</Button>
			<Button type="submit" loading={saving}
				>{editing === 'new' ? m.create_button() : m.save_button()}</Button
			>
		</div>
	</form>
</Dialog>

<Dialog open={issued !== null} title={m.users_password_title()} onclose={() => (issued = null)}>
	{#if issued}
		<p class="muted">{m.users_password_body({ email: issued.email })}</p>
		<div class="secret">
			<code>{issued.password}</code>
			<Button variant="secondary" onclick={copy}>
				{#if copied}<Check size={16} aria-hidden="true" />{:else}<Copy
						size={16}
						aria-hidden="true"
					/>{/if}
				{copied ? m.share_copied() : m.share_copy()}
			</Button>
		</div>
		<div class="actions">
			<Button onclick={() => (issued = null)}>{m.share_done()}</Button>
		</div>
	{/if}
</Dialog>

<Dialog
	open={deleting !== null}
	title={m.users_delete_title({ email: deleting?.email ?? '' })}
	onclose={() => (deleting = null)}
>
	<p class="muted">{m.users_delete_body()}</p>
	<TextField label={m.users_delete_confirm()} bind:value={confirmEmail} autocomplete="off" />
	<div class="actions">
		<Button variant="ghost" onclick={() => (deleting = null)}>{m.cancel_button()}</Button>
		<Button
			variant="danger"
			disabled={confirmEmail.trim().toLowerCase() !== deleting?.email.toLowerCase()}
			onclick={remove}>{m.users_delete()}</Button
		>
	</div>
</Dialog>

<style>
	.head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-4);
		margin-top: var(--space-2);
	}
	h1 {
		font-size: var(--text-2xl);
		letter-spacing: -0.02em;
	}
	.status {
		min-height: var(--space-5);
		margin: var(--space-2) 0;
		color: var(--color-success);
		font-size: var(--text-sm);
	}
	.list {
		max-width: 56rem;
		margin: 0;
		padding: 0;
		list-style: none;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
	}
	.row {
		display: flex;
		align-items: center;
		gap: var(--space-4);
		padding: var(--space-3) var(--space-4);
	}
	.row + .row {
		border-top: 1px solid var(--color-border);
	}
	.who {
		display: grid;
		flex: 1;
		min-width: 0;
	}
	.name {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-2);
		font-weight: var(--weight-medium);
	}
	.badge {
		display: inline-flex;
		align-items: center;
		gap: 3px;
		padding: 0 var(--space-2);
		border-radius: var(--radius-full);
		background: var(--color-accent-subtle);
		color: var(--color-accent);
		font-size: var(--text-xs);
		font-weight: var(--weight-medium);
	}
	.badge.subtle {
		background: var(--color-surface-sunken);
		color: var(--color-text-muted);
	}
	.usage {
		display: grid;
		gap: var(--space-1);
		min-width: 9rem;
		text-align: right;
	}
	.bar {
		display: block;
		height: 4px;
		overflow: hidden;
		border-radius: var(--radius-full);
		background: var(--color-surface-sunken);
	}
	.bar span {
		display: block;
		height: 100%;
		background: var(--color-accent);
	}
	.muted {
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.small {
		margin: 0;
		font-size: var(--text-xs);
	}
	.form {
		display: grid;
		gap: var(--space-4);
	}
	.check {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		min-height: 2.75rem;
	}
	.check input {
		width: 1.25rem;
		height: 1.25rem;
		accent-color: var(--color-accent);
	}
	.secret {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		margin: var(--space-4) 0;
	}
	.secret code {
		flex: 1;
		padding: var(--space-3);
		border-radius: var(--radius-md);
		background: var(--color-surface-sunken);
		font-family: var(--font-mono);
		font-size: var(--text-md);
		letter-spacing: 0.04em;
	}
	.actions {
		display: flex;
		justify-content: flex-end;
		gap: var(--space-2);
		margin-top: var(--space-4);
	}
	@media (max-width: 640px) {
		.row {
			flex-wrap: wrap;
		}
		.usage {
			order: 3;
			width: 100%;
			text-align: left;
		}
	}
</style>
