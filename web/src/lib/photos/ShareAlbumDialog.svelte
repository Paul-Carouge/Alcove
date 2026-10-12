<script lang="ts">
	import { X } from '@lucide/svelte';
	import { m } from '#lib/paraglide/messages.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Avatar from '#lib/ui/Avatar.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';
	import TextField from '#lib/ui/TextField.svelte';
	import {
		getPeople,
		lookupUser,
		shareAlbum,
		type Participant,
		type Person,
		type Role
	} from './albums.js';

	let {
		open = $bindable(false),
		albumId,
		onsaved
	}: { open?: boolean; albumId: string; onsaved?: () => void } = $props();

	let owner = $state<Person | null>(null);
	let people = $state<Participant[]>([]);
	let email = $state('');
	let role = $state<Role>('viewer');
	let emailError = $state<string | null>(null);
	let failed = $state(false);
	let adding = $state(false);
	let saving = $state(false);
	const uid = $props.id();

	$effect(() => {
		if (!open) return;
		owner = null;
		people = [];
		email = '';
		emailError = null;
		failed = false;
		getPeople(albumId)
			.then((p) => {
				owner = p.owner;
				people = p.people;
			})
			.catch(() => (failed = true));
	});

	async function add(event: SubmitEvent) {
		event.preventDefault();
		const value = email.trim();
		emailError = null;
		if (!/^[^\s@]+@[^\s@]+$/.test(value)) {
			emailError = m.error_email_invalid();
			return;
		}
		if (people.some((p) => p.email.toLowerCase() === value.toLowerCase())) {
			emailError = m.album_share_already();
			return;
		}
		adding = true;
		try {
			const found = await lookupUser(value);
			if (!found) emailError = m.album_share_unknown();
			else {
				people = [...people, { ...found, role }];
				email = '';
			}
		} catch {
			failed = true;
		} finally {
			adding = false;
		}
	}

	async function save() {
		saving = true;
		try {
			await shareAlbum(albumId, people);
			open = false;
			onsaved?.();
		} catch {
			failed = true;
		} finally {
			saving = false;
		}
	}
</script>

<Dialog bind:open title={m.album_share_title()}>
	<p class="intro">{m.album_share_intro()}</p>
	<form class="add" onsubmit={add} novalidate>
		<TextField
			label={m.email_label()}
			type="email"
			bind:value={email}
			autocomplete="off"
			error={emailError}
		/>
		<label class="sr-only" for="role-{uid}">{m.album_role_label()}</label>
		<select id="role-{uid}" bind:value={role}>
			<option value="viewer">{m.album_role_viewer()}</option>
			<option value="contributor">{m.album_role_contributor()}</option>
		</select>
		<Button type="submit" variant="secondary" loading={adding}>{m.album_share_add()}</Button>
	</form>

	{#if failed}<Alert>{m.error_unexpected()}</Alert>{/if}

	<ul class="people" aria-label={m.album_people()}>
		{#if owner}
			<li>
				<Avatar name={owner.name} email={owner.email} />
				<span class="who"
					><span class="name">{owner.name || owner.email}</span><span class="muted"
						>{owner.email}</span
					></span
				>
				<span class="muted">{m.album_role_owner()}</span>
			</li>
		{/if}
		{#each people as p, i (p.id)}
			<li>
				<Avatar name={p.name} email={p.email} />
				<span class="who"
					><span class="name">{p.name || p.email}</span><span class="muted">{p.email}</span></span
				>
				<select
					aria-label={m.album_role_for({ name: p.name || p.email })}
					bind:value={people[i]!.role}
				>
					<option value="viewer">{m.album_role_viewer()}</option>
					<option value="contributor">{m.album_role_contributor()}</option>
				</select>
				<button
					class="icon-btn"
					aria-label={m.album_share_remove({ name: p.name || p.email })}
					onclick={() => (people = people.filter((x) => x.id !== p.id))}
				>
					<X size={18} aria-hidden="true" />
				</button>
			</li>
		{/each}
	</ul>

	<div class="actions">
		<Button variant="ghost" onclick={() => (open = false)}>{m.cancel_button()}</Button>
		<Button loading={saving} onclick={save}>{m.save_button()}</Button>
	</div>
</Dialog>

<style>
	.intro {
		margin: 0 0 var(--space-4);
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.add {
		display: grid;
		grid-template-columns: 1fr auto;
		align-items: end;
		gap: var(--space-2);
	}
	.add :global(.field) {
		grid-column: 1 / -1;
	}
	select {
		min-height: 2.75rem;
		padding: 0 var(--space-3);
		border: 1px solid var(--color-border-strong);
		border-radius: var(--radius-md);
		background: var(--color-surface);
		color: var(--color-text);
		font: inherit;
		font-size: var(--text-sm);
	}
	.people {
		display: grid;
		gap: var(--space-2);
		margin: var(--space-5) 0 0;
		padding: 0;
		list-style: none;
	}
	.people li {
		display: grid;
		grid-template-columns: auto 1fr auto;
		align-items: center;
		gap: var(--space-1) var(--space-3);
	}
	/* Role under the name, so names are not cut short. */
	.people li select {
		grid-column: 2;
		grid-row: 2;
		justify-self: start;
	}
	.people li .icon-btn {
		grid-column: 3;
		grid-row: 1 / span 2;
	}
	.who {
		display: grid;
		min-width: 0;
	}
	.name,
	.who .muted {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.name {
		font-weight: var(--weight-medium);
	}
	.muted {
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.icon-btn {
		display: grid;
		place-items: center;
		width: 2.75rem;
		height: 2.75rem;
		border: 0;
		border-radius: var(--radius-md);
		background: transparent;
		color: var(--color-text-muted);
		cursor: pointer;
	}
	.icon-btn:hover {
		background: var(--color-surface-sunken);
		color: var(--color-text);
	}
	.actions {
		display: flex;
		justify-content: flex-end;
		gap: var(--space-2);
		margin-top: var(--space-5);
	}
	.sr-only {
		position: absolute;
		width: 1px;
		height: 1px;
		overflow: hidden;
		clip-path: inset(50%);
		white-space: nowrap;
	}
</style>
