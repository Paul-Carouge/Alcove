<script lang="ts">
	import { FolderPlus, Upload } from '@lucide/svelte';
	import { m } from '#lib/paraglide/messages.js';
	import Button from '#lib/ui/Button.svelte';
</script>

<svelte:head>
	<title>{m.files_title()}</title>
</svelte:head>

<div class="head">
	<h1>{m.files_title()}</h1>
	<div class="actions">
		<Button variant="secondary" disabled title={m.coming_soon()}>
			<FolderPlus size={18} aria-hidden="true" />
			{m.new_folder_button()}
		</Button>
		<Button disabled title={m.coming_soon()}>
			<Upload size={18} aria-hidden="true" />
			{m.upload_button()}
		</Button>
	</div>
</div>

<section class="empty" aria-labelledby="empty-title">
	<div class="art" aria-hidden="true">
		<div class="sheet back"></div>
		<div class="sheet mid"></div>
		<div class="sheet front"><Upload size={22} /></div>
	</div>
	<h2 id="empty-title">{m.files_empty_title()}</h2>
	<p>{m.files_empty_body()}</p>
</section>

<style>
	.head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		flex-wrap: wrap;
		gap: var(--space-4);
		margin-bottom: var(--space-5);
	}
	h1 {
		font-size: var(--text-2xl);
		letter-spacing: -0.02em;
	}
	.actions {
		display: flex;
		gap: var(--space-2);
	}
	.empty {
		display: grid;
		justify-items: center;
		gap: var(--space-2);
		padding: var(--space-8) var(--space-5);
		border: 1.5px dashed var(--color-border-strong);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
		text-align: center;
	}
	.art {
		position: relative;
		width: 5.5rem;
		height: 5rem;
		margin-bottom: var(--space-4);
	}
	.sheet {
		position: absolute;
		inset: 0;
		border-radius: var(--radius-md);
		border: 1px solid var(--color-border);
		background: var(--color-surface-raised);
		box-shadow: var(--shadow-sm);
	}
	.back {
		transform: rotate(-10deg) translate(-10px, 4px);
		background: var(--color-surface-sunken);
	}
	.mid {
		transform: rotate(6deg) translate(8px, 2px);
	}
	.front {
		display: grid;
		place-items: center;
		color: var(--color-accent);
		background: var(--color-accent-subtle);
		border-color: transparent;
		box-shadow: var(--shadow-md);
	}
	h2 {
		font-size: var(--text-lg);
	}
	p {
		margin: 0;
		max-width: 28rem;
		color: var(--color-text-muted);
	}
</style>
