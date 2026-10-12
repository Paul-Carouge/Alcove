<script lang="ts">
	import { resolve } from '$app/paths';
	import { LogOut, Monitor, Moon, Shield, Sun } from '@lucide/svelte';
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
	let root: HTMLDivElement;
	let trigger: HTMLButtonElement;

	const modes: { value: ThemeMode; label: () => string; icon: typeof Sun }[] = [
		{ value: 'system', label: m.theme_system, icon: Monitor },
		{ value: 'light', label: m.theme_light, icon: Sun },
		{ value: 'dark', label: m.theme_dark, icon: Moon }
	];

	function close(focusTrigger = false) {
		open = false;
		if (focusTrigger) trigger.focus();
	}

	// pointerdown (not click): a click can re-render its own target, which is then
	// detached from the DOM and would look like an outside click.
	function onWindowPointerDown(e: PointerEvent) {
		if (open && !root.contains(e.target as Node)) close();
	}
</script>

<svelte:window
	onpointerdown={onWindowPointerDown}
	onkeydown={(e) => open && e.key === 'Escape' && close(true)}
/>

<div class="wrap" bind:this={root}>
	<button
		bind:this={trigger}
		class="trigger"
		aria-expanded={open}
		aria-controls="user-menu"
		aria-label={m.account_menu()}
		onclick={() => (open = !open)}
	>
		<Avatar {name} {email} />
	</button>

	{#if open}
		<div class="panel" id="user-menu">
			<div class="who">
				<Avatar {name} {email} size={40} />
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

			<a class="item link" href={resolve('/(app)/security')} onclick={() => close()}>
				<Shield size={16} aria-hidden="true" />
				{m.nav_security()}
			</a>
			<button class="item danger" onclick={onsignout}>
				<LogOut size={16} aria-hidden="true" />
				{m.sign_out_button()}
			</button>
		</div>
	{/if}
</div>

<style>
	.wrap {
		position: relative;
	}
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
	}
	.trigger:hover {
		background: var(--color-surface-sunken);
	}
	.panel {
		position: absolute;
		right: 0;
		top: calc(100% + var(--space-2));
		z-index: 20;
		width: 18rem;
		padding: var(--space-2);
		background: var(--color-surface-raised);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		box-shadow: var(--shadow-lg);
		display: grid;
		gap: var(--space-1);
		animation: pop var(--duration-base) var(--ease-emphasized);
		transform-origin: top right;
	}
	@keyframes pop {
		from {
			opacity: 0;
			transform: scale(0.96) translateY(-4px);
		}
	}
	.who {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-3);
		border-bottom: 1px solid var(--color-border);
		margin-bottom: var(--space-1);
	}
	.ids {
		display: grid;
		min-width: 0;
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
		padding: var(--space-1) var(--space-3);
	}
	.label {
		font-size: var(--text-sm);
		color: var(--color-text-muted);
	}
	.segmented {
		display: inline-flex;
		padding: 2px;
		gap: 2px;
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
	}
	.segmented button[aria-checked='true'] {
		background: var(--color-surface);
		color: var(--color-text);
		box-shadow: var(--shadow-sm);
	}
	.item {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		min-height: 2.75rem;
		padding: 0 var(--space-3);
		margin-top: var(--space-1);
		border: 0;
		border-top: 1px solid var(--color-border);
		border-radius: 0 0 var(--radius-md) var(--radius-md);
		background: transparent;
		font: inherit;
		color: var(--color-text);
		cursor: pointer;
		text-align: left;
	}
	.item.link {
		border-top: 1px solid var(--color-border);
		border-radius: 0;
		text-decoration: none;
	}
	.item.link + .item {
		margin-top: 0;
	}
	.item:hover {
		background: var(--color-surface-sunken);
	}
	.danger {
		color: var(--color-danger);
	}
</style>
