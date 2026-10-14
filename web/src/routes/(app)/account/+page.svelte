<script lang="ts">
	import { resolve } from '$app/paths';
	import { ClientResponseError } from 'pocketbase';
	import { Download, Shield, Smartphone } from '@lucide/svelte';
	import { ANDROID_APK_URL } from '#lib/brand.js';
	import { session } from '#lib/auth/session.svelte.js';
	import { MIN_PASSWORD_LENGTH, PASSWORD_CHANGED } from '#lib/auth/validation.js';
	import { fileToken } from '#lib/drive/files.js';
	import { m } from '#lib/paraglide/messages.js';
	import { pb } from '#lib/pb.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Avatar from '#lib/ui/Avatar.svelte';
	import Button from '#lib/ui/Button.svelte';
	import TextField from '#lib/ui/TextField.svelte';

	let name = $state(session.user?.name ?? '');
	let nameSaved = $state(false);
	let savingName = $state(false);

	let current = $state('');
	let next = $state('');
	let confirm = $state('');
	let pwError = $state<{ current?: string; next?: string; confirm?: string; form?: string }>({});
	let savingPw = $state(false);

	// Prefer the app served by this server (same version as the server, ADR 0024); fall back to
	// the latest release on GitHub when the server has none to offer.
	let serverApk = $state<{ version: string; size?: number } | null>(null);
	$effect(() => {
		pb.send<{ version: string; available: boolean; size?: number }>('/api/v1/app/android', {})
			.then((r) => (serverApk = r.available ? r : null))
			.catch(() => (serverApk = null));
	});

	async function downloadFromServer(event: MouseEvent) {
		event.preventDefault();
		const url = new URL(pb.buildURL('/api/v1/app/android.apk'), location.href);
		url.searchParams.set('token', await fileToken());
		location.assign(url.toString());
	}

	async function saveName(event: SubmitEvent) {
		event.preventDefault();
		if (!session.user) return;
		savingName = true;
		nameSaved = false;
		try {
			await pb.collection('users').update(session.user.id, { name: name.trim() });
			nameSaved = true;
		} finally {
			savingName = false;
		}
	}

	async function savePassword(event: SubmitEvent) {
		event.preventDefault();
		if (!session.user) return;
		pwError = {
			current: current ? undefined : m.error_field_required(),
			next: next.length >= MIN_PASSWORD_LENGTH ? undefined : m.error_password_short(),
			confirm: confirm === next ? undefined : m.error_password_mismatch()
		};
		if (pwError.current || pwError.next || pwError.confirm) return;
		savingPw = true;
		try {
			await pb.collection('users').update(session.user.id, {
				oldPassword: current,
				password: next,
				passwordConfirm: confirm
			});
			// The server signs the account out everywhere: sign in again with the new password.
			// The layout sends signed-out users to the login page; leave it a note for this tab.
			try {
				sessionStorage.setItem(PASSWORD_CHANGED, '1');
			} catch {
				// Storage unavailable: the login page simply shows no notice.
			}
			session.signOut();
		} catch (err) {
			pwError =
				err instanceof ClientResponseError && err.response?.data?.oldPassword
					? { current: m.account_wrong_password() }
					: { form: m.error_unexpected() };
		} finally {
			savingPw = false;
		}
	}
</script>

<svelte:head>
	<title>{m.account_title()}</title>
</svelte:head>

<h1>{m.account_title()}</h1>

<section class="card" aria-labelledby="profile-title">
	<h2 id="profile-title">{m.account_profile()}</h2>
	<div class="who">
		<Avatar {name} email={session.user?.email ?? ''} size={48} />
		<span class="muted">{session.user?.email}</span>
	</div>
	<form onsubmit={saveName} class="form">
		<TextField label={m.users_name()} bind:value={name} maxlength={100} autocomplete="name" />
		<div class="actions">
			{#if nameSaved}<span class="ok" role="status">{m.account_saved()}</span>{/if}
			<Button type="submit" variant="secondary" loading={savingName}>{m.save_button()}</Button>
		</div>
	</form>
</section>

<section class="card" aria-labelledby="password-title">
	<h2 id="password-title">{m.account_password()}</h2>
	<p class="muted">{m.account_password_note()}</p>
	<form onsubmit={savePassword} class="form" novalidate>
		<TextField
			label={m.account_current_password()}
			type="password"
			autocomplete="current-password"
			bind:value={current}
			error={pwError.current}
		/>
		<TextField
			label={m.new_password_label()}
			type="password"
			autocomplete="new-password"
			bind:value={next}
			error={pwError.next}
		/>
		<TextField
			label={m.confirm_password_label()}
			type="password"
			autocomplete="new-password"
			bind:value={confirm}
			error={pwError.confirm}
		/>
		{#if pwError.form}<Alert>{pwError.form}</Alert>{/if}
		<div class="actions">
			<Button type="submit" loading={savingPw}>{m.account_change_password()}</Button>
		</div>
	</form>
</section>

<section class="card" aria-labelledby="mobile-title">
	<h2 id="mobile-title"><Smartphone size={20} aria-hidden="true" />{m.account_mobile()}</h2>
	<p class="muted">{m.account_mobile_body()}</p>
	<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- external download -->
	{#if serverApk}
		<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- API download -->
		<a class="download" href={pb.buildURL('/api/v1/app/android.apk')} onclick={downloadFromServer}>
			<Download size={18} aria-hidden="true" />{m.account_mobile_android()}
			<span class="version">v{serverApk.version}</span>
		</a>
	{:else}
		<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- external download -->
		<a class="download" href={ANDROID_APK_URL} rel="noopener noreferrer">
			<Download size={18} aria-hidden="true" />{m.account_mobile_android()}
		</a>
	{/if}
	<p class="muted small">{m.account_mobile_update()}</p>
	<p class="muted small">{m.account_mobile_ios()}</p>
</section>

<a class="security" href={resolve('/(app)/security')}>
	<Shield size={18} aria-hidden="true" />{m.nav_security()}
</a>

<style>
	h1 {
		margin: 0 0 var(--space-6);
		padding-top: var(--space-3);
	}
	.card {
		max-width: 40rem;
		margin-bottom: var(--space-5);
		padding: var(--space-6);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-xl);
		background: var(--color-surface);
		box-shadow: var(--shadow-sm);
	}
	h2 {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		font-size: var(--text-xl);
		margin-bottom: var(--space-2);
	}
	.who {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		margin: var(--space-4) 0 var(--space-5);
		padding: var(--space-3);
		border-radius: var(--radius-lg);
		background: var(--color-surface-sunken);
	}
	.muted {
		margin: 0 0 var(--space-4);
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.who .muted {
		margin: 0;
	}
	.form {
		display: grid;
		gap: var(--space-4);
	}
	.actions {
		display: flex;
		align-items: center;
		justify-content: flex-end;
		gap: var(--space-3);
		margin-top: var(--space-1);
	}
	.ok {
		color: var(--color-success);
		font-size: var(--text-sm);
	}
	h2 :global(svg) {
		flex: none;
		color: var(--color-accent);
	}
	.download {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		min-height: 2.75rem;
		margin: 0 0 var(--space-4);
		padding: 0 var(--space-4);
		border-radius: var(--radius-md);
		background: var(--color-accent);
		color: var(--color-accent-contrast);
		box-shadow: var(--shadow-sm);
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		text-decoration: none;
		transition: background var(--duration-fast) var(--ease-standard);
	}
	.version {
		font-size: var(--text-xs);
		opacity: 0.8;
	}
	.download:hover {
		background: var(--color-accent-hover);
	}
	.small {
		margin: 0 0 var(--space-1);
		font-size: var(--text-xs);
	}
	.security {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		min-height: 2.75rem;
		color: var(--color-accent);
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
	}
	@media (max-width: 600px) {
		.card {
			padding: var(--space-5) var(--space-4);
		}
		.actions :global(.btn) {
			flex: 1;
		}
	}
</style>
