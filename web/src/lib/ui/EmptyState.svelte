<script lang="ts">
	import type { Component, Snippet } from 'svelte';

	// DESIGN.md "EmptyState": an icon, one sentence, at most one action.
	// The icon sits in a small arch, the alcove of the logo.
	let {
		icon: Icon,
		title,
		level = 2,
		compact = false,
		children,
		action
	}: {
		icon?: Component<{ size?: number; strokeWidth?: number }>;
		title: string;
		/** 1 when the empty state is the whole page (e.g. a missing album). */
		level?: 1 | 2;
		/** Less padding, for empty states inside a card or a dialog. */
		compact?: boolean;
		children?: Snippet;
		action?: Snippet;
	} = $props();

	const uid = $props.id();
</script>

<section class="empty" class:compact aria-labelledby="empty-{uid}">
	{#if Icon}
		<span class="art" aria-hidden="true"><Icon size={24} strokeWidth={1.75} /></span>
	{/if}
	<svelte:element this={level === 1 ? 'h1' : 'h2'} id="empty-{uid}" class="title">
		{title}
	</svelte:element>
	{#if children}<p>{@render children()}</p>{/if}
	{#if action}<div class="action">{@render action()}</div>{/if}
</section>

<style>
	.empty {
		display: grid;
		justify-items: center;
		gap: var(--space-3);
		padding: var(--space-8) var(--space-5);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-xl);
		background:
			radial-gradient(60% 70% at 50% 0%, var(--color-accent-subtle), transparent 70%),
			var(--color-surface);
		text-align: center;
		animation: rise var(--duration-slow) var(--ease-emphasized);
	}
	.compact {
		padding: var(--space-6) var(--space-4);
	}
	@keyframes rise {
		from {
			opacity: 0;
			transform: translateY(var(--space-2));
		}
	}
	.art {
		position: relative;
		display: grid;
		place-items: center;
		width: 4rem;
		height: 4.75rem;
		margin-bottom: var(--space-3);
		padding-top: var(--space-3);
		border-radius: var(--radius-full) var(--radius-full) var(--radius-md) var(--radius-md);
		background: var(--color-accent-subtle);
		color: var(--color-accent);
		box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--color-accent) 16%, transparent);
	}
	/* A second, hairline arch around the first. */
	.art::before {
		content: '';
		position: absolute;
		inset: calc(-1 * var(--space-2)) calc(-1 * var(--space-2)) 0;
		border: 1px solid var(--color-border-strong);
		border-bottom: 0;
		border-radius: var(--radius-full) var(--radius-full) 0 0;
		opacity: 0.5;
	}
	.title {
		font-size: var(--text-2xl);
		font-weight: var(--weight-regular);
	}
	.compact .title {
		font-size: var(--text-xl);
	}
	p {
		margin: 0;
		max-width: 30rem;
		color: var(--color-text-muted);
	}
	.action {
		margin-top: var(--space-2);
	}
	@media (max-width: 600px) {
		.empty {
			padding: var(--space-7) var(--space-4);
		}
	}
</style>
