<script lang="ts">
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import { formatSize } from './format.js';
	import { usage, WARN_RATIO } from './usage.svelte.js';

	const locale = getLocale();
	const u = $derived(usage.current);
	const warn = $derived(usage.ratio >= WARN_RATIO);
</script>

{#if u}
	<section class="meter" class:warn aria-labelledby="storage-title">
		<h2 id="storage-title">{m.storage_label()}</h2>
		{#if u.quota > 0}
			<progress
				max={u.quota}
				value={Math.min(u.used, u.quota)}
				aria-label={m.storage_used({
					used: formatSize(u.used, locale),
					quota: formatSize(u.quota, locale)
				})}
			></progress>
			<p>
				{m.storage_used({ used: formatSize(u.used, locale), quota: formatSize(u.quota, locale) })}
			</p>
		{:else}
			<p>{m.storage_used_unlimited({ used: formatSize(u.used, locale) })}</p>
		{/if}
		{#if u.trash > 0}<p class="sub">
				{m.storage_trash({ trash: formatSize(u.trash, locale) })}
			</p>{/if}
		{#if warn}<p class="alert" role="status">{m.storage_almost_full()}</p>{/if}
	</section>
{/if}

<style>
	.meter {
		display: grid;
		gap: var(--space-2);
		padding: var(--space-4);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
		box-shadow: var(--shadow-sm);
	}
	h2 {
		font-family: var(--font-sans);
		font-size: var(--text-xs);
		font-weight: var(--weight-medium);
		text-transform: uppercase;
		letter-spacing: 0.08em;
		color: var(--color-text-muted);
	}
	p {
		margin: 0;
		font-size: var(--text-sm);
		color: var(--color-text);
		font-variant-numeric: tabular-nums;
	}
	.sub {
		font-size: var(--text-xs);
	}
	.sub {
		color: var(--color-text-muted);
	}
	progress {
		width: 100%;
		height: var(--space-1);
		appearance: none;
		border: 0;
		border-radius: var(--radius-full);
		background: var(--color-border);
		overflow: hidden;
	}
	progress::-webkit-progress-bar {
		background: var(--color-border);
	}
	progress::-webkit-progress-value {
		background: var(--color-accent);
	}
	progress::-moz-progress-bar {
		background: var(--color-accent);
	}
	.warn progress::-webkit-progress-value {
		background: var(--color-danger);
	}
	.warn progress::-moz-progress-bar {
		background: var(--color-danger);
	}
	.alert {
		color: var(--color-danger);
	}
</style>
