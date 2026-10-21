<script lang="ts">
	import { resolve } from '$app/paths';
	import {
		LogOut,
		Monitor,
		Moon,
		Server,
		Shield,
		Sun,
		User as UserIcon,
		Users
	} from '@lucide/svelte';
	import { Popover } from 'bits-ui';
	import { session } from '#lib/auth/session.svelte.js';
	import { m } from '#lib/paraglide/messages.js';
	import { theme, type ThemeMode } from '#lib/theme/theme.svelte.js';
	import Avatar from './Avatar.svelte';
	import LanguageSelect from './LanguageSelect.svelte';

	let {
		name = '',
		email,
		onsignout
	}: { name?: string; email: string; onsignout: () => void } = $props();

	let open = $state(false);

	const modes: { value: ThemeMode; label: () => string; icon: typeof Sun }[] = [
		{ value: 'system', label: m.theme_system, icon: Monitor },
		{ value: 'light', label: m.theme_light, icon: Sun },
		{ value: 'dark', label: m.theme_dark, icon: Moon }
	];
</script>

<Popover.Root bind:open>
	<Popover.Trigger aria-label={m.account_menu()}>
		{#snippet child({ props })}
			<button {...props} class="trigger">
				<Avatar {name} {email} size={36} />
			</button>
		{/snippet}
	</Popover.Trigger>
	<Popover.Portal>
		<Popover.Content
			align="end"
			sideOffset={8}
			collisionPadding={12}
			role="dialog"
			aria-label={m.account_menu()}
		>
			{#snippet child({ wrapperProps, props })}
				<div {...wrapperProps}>
					<div {...props} class="panel">
						<div class="who">
							<Avatar {name} {email} size={44} />
							<div class="ids">
								{#if name}<strong>{name}</strong>{/if}
								<span class="email">{email}</span>
							</div>
						</div>

						<div class="row">
							<span class="label" id="theme-label">{m.theme_label()}</span>
							<div class="segmented" role="radiogroup" aria-labelledby="theme-label">
								{#each modes as mode (mode.value)}
									<button
										role="radio"
										aria-checked={theme.mode === mode.value}
										aria-label={mode.label()}
										title={mode.label()}
										onclick={() => theme.set(mode.value)}
									>
										<mode.icon size={16} aria-hidden="true" />
									</button>
								{/each}
							</div>
						</div>

						<div class="row">
							<span class="label">{m.language()}</span>
							<LanguageSelect />
						</div>

						<hr />
						<a class="item" href={resolve('/(app)/account')} onclick={() => (open = false)}>
							<UserIcon size={18} aria-hidden="true" />
							{m.account_title()}
						</a>
						<a class="item" href={resolve('/(app)/security')} onclick={() => (open = false)}>
							<Shield size={18} aria-hidden="true" />
							{m.nav_security()}
						</a>
						{#if session.isAdmin}
							<a class="item" href={resolve('/(app)/admin/users')} onclick={() => (open = false)}>
								<Users size={18} aria-hidden="true" />
								{m.users_title()}
							</a>
							<a class="item" href={resolve('/(app)/admin/system')} onclick={() => (open = false)}>
								<Server size={18} aria-hidden="true" />
								{m.nav_system()}
							</a>
						{/if}
						<hr />
						<button class="item danger" onclick={onsignout}>
							<LogOut size={18} aria-hidden="true" />
							{m.sign_out_button()}
						</button>
					</div>
				</div>
			{/snippet}
		</Popover.Content>
	</Popover.Portal>
</Popover.Root>

<style>
	.trigger {
		display: grid;
		place-items: center;
		width: 2.75rem;
		height: 2.75rem;
		padding: 0;
		border: 0;
		border-radius: var(--radius-full);
		background: transparent;
		cursor: pointer;
		transition: box-shadow var(--duration-fast) var(--ease-standard);
	}
	.trigger:hover,
	.trigger[data-state='open'] {
		box-shadow: 0 0 0 3px var(--color-accent-subtle);
	}
	.panel {
		z-index: 50;
		width: 19rem;
		max-width: calc(100vw - 2 * var(--space-3));
		max-height: var(--bits-floating-available-height);
		overflow-y: auto;
		padding: var(--space-2);
		background: var(--color-surface-raised);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-xl);
		box-shadow: var(--shadow-lg);
		display: grid;
		gap: 1px;
		animation: pop var(--duration-base) var(--ease-emphasized);
		transform-origin: var(--bits-floating-transform-origin);
		outline: none;
	}
	@keyframes pop {
		from {
			opacity: 0;
			transform: scale(0.96);
		}
	}
	.who {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-3);
		margin-bottom: var(--space-2);
		border-radius: var(--radius-lg);
		background: var(--color-surface-sunken);
	}
	.ids {
		display: grid;
		min-width: 0;
	}
	.ids strong {
		font-family: var(--font-display);
		font-size: var(--text-lg);
		font-weight: var(--weight-medium);
		line-height: var(--leading-tight);
	}
	.email {
		font-size: var(--text-sm);
		color: var(--color-text-muted);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
		padding: var(--space-1) var(--space-1) var(--space-1) var(--space-3);
	}
	.label {
		font-size: var(--text-sm);
		color: var(--color-text-muted);
	}
	.segmented {
		display: inline-flex;
		padding: var(--space-1);
		gap: var(--space-1);
		background: var(--color-surface-sunken);
		border-radius: var(--radius-md);
	}
	.segmented button {
		display: grid;
		place-items: center;
		width: 2.75rem;
		height: 2.25rem;
		border: 0;
		border-radius: var(--radius-sm);
		background: transparent;
		color: var(--color-text-muted);
		cursor: pointer;
		transition:
			background var(--duration-fast) var(--ease-standard),
			color var(--duration-fast) var(--ease-standard);
	}
	.segmented button:hover {
		color: var(--color-text);
	}
	.segmented button[aria-checked='true'] {
		background: var(--color-surface-raised);
		color: var(--color-accent);
		box-shadow: var(--shadow-sm);
	}
	hr {
		width: 100%;
		margin: var(--space-2) 0;
		border: 0;
		border-top: 1px solid var(--color-border);
	}
	.item {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		min-height: 2.75rem;
		padding: 0 var(--space-3);
		border: 0;
		border-radius: var(--radius-md);
		background: transparent;
		font: inherit;
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		color: var(--color-text);
		cursor: pointer;
		text-align: left;
		text-decoration: none;
		transition: background var(--duration-fast) var(--ease-standard);
	}
	.item :global(svg) {
		color: var(--color-text-muted);
	}
	.item:hover {
		background: var(--color-surface-sunken);
	}
	.danger,
	.danger :global(svg) {
		color: var(--color-danger);
	}
</style>
