<script lang="ts">
	import { ChevronLeft, ChevronRight, Download, ExternalLink, X } from '@lucide/svelte';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import FileIcon from './FileIcon.svelte';
	import { contentUrl, fileToken, hasThumbnail, previewKind, thumbUrl } from './files.js';
	import { formatSize } from './format.js';
	import type { DriveNode } from './types.js';

	let {
		items,
		index = $bindable(-1),
		ondownload
	}: { items: DriveNode[]; index?: number; ondownload: (node: DriveNode) => void } = $props();

	const TEXT_LIMIT = 256 * 1024;

	let dialog: HTMLDialogElement;
	let token = $state('');
	let text = $state<string | null>(null);

	const node = $derived(index >= 0 ? items[index] : undefined);
	const kind = $derived(node ? previewKind(node) : null);

	$effect(() => {
		if (node && !dialog.open) dialog.showModal();
		if (!node && dialog.open) dialog.close();
	});

	$effect(() => {
		const current = node;
		text = null;
		if (!current) return;
		fileToken().then(async (t) => {
			if (current !== node) return;
			token = t;
			if (previewKind(current) === 'text') {
				// The download route honors Range: fetch only the beginning.
				const res = await fetch(contentUrl(current, t), {
					headers: { Range: `bytes=0-${TEXT_LIMIT - 1}` }
				});
				if (current === node) text = res.ok ? await res.text() : '';
			}
		});
	});

	function go(step: number) {
		if (items.length > 1) index = (index + step + items.length) % items.length;
	}

	function onKeydown(e: KeyboardEvent) {
		if (e.key === 'ArrowRight') go(1);
		else if (e.key === 'ArrowLeft') go(-1);
		else return;
		e.preventDefault();
	}
</script>

<dialog
	bind:this={dialog}
	class="viewer"
	aria-label={node?.name ?? ''}
	onclose={() => (index = -1)}
	onkeydown={onKeydown}
>
	{#if node}
		<header>
			<div class="title">
				<FileIcon kind={node.kind} mime={node.mime} size={18} />
				<div class="ids">
					<h2>{node.name}</h2>
					<span>
						{formatSize(node.size, getLocale())}
						{#if items.length > 1}· {m.viewer_position({
								index: index + 1,
								total: items.length
							})}{/if}
					</span>
				</div>
			</div>
			<div class="tools">
				{#if kind === 'pdf' && token}
					<!-- An API URL for the browser's PDF viewer, not an app route. -->
					<button
						class="icon-btn"
						aria-label={m.open_pdf()}
						title={m.open_pdf()}
						onclick={() => window.open(contentUrl(node, token), '_blank', 'noopener')}
					>
						<ExternalLink size={20} aria-hidden="true" />
					</button>
				{/if}
				<button
					class="icon-btn"
					aria-label={m.action_download()}
					title={m.action_download()}
					onclick={() => ondownload(node)}
				>
					<Download size={20} aria-hidden="true" />
				</button>
				<button
					class="icon-btn"
					aria-label={m.viewer_close()}
					title={m.viewer_close()}
					onclick={() => (index = -1)}
				>
					<X size={20} aria-hidden="true" />
				</button>
			</div>
		</header>

		<div class="stage">
			{#if items.length > 1}
				<button class="nav prev" aria-label={m.viewer_prev()} onclick={() => go(-1)}>
					<ChevronLeft size={24} aria-hidden="true" />
				</button>
			{/if}

			{#if !token}
				<span class="muted">{m.loading()}</span>
			{:else if kind === 'image'}
				{#key node.id}
					<img
						src={hasThumbnail(node) ? thumbUrl(node, '1600x0', token) : contentUrl(node, token)}
						alt={node.name}
					/>
				{/key}
			{:else if kind === 'video'}
				<!-- svelte-ignore a11y_media_has_caption -->
				<video src={contentUrl(node, token)} controls preload="metadata"></video>
			{:else if kind === 'audio'}
				<audio src={contentUrl(node, token)} controls preload="metadata"></audio>
			{:else if kind === 'pdf'}
				<iframe src={contentUrl(node, token)} title={node.name}></iframe>
			{:else if kind === 'text'}
				<div class="text">
					{#if text === null}
						<span class="muted">{m.loading()}</span>
					{:else}
						<pre>{text}</pre>
						{#if node.size > TEXT_LIMIT}<p class="muted">{m.viewer_text_truncated()}</p>{/if}
					{/if}
				</div>
			{:else}
				<div class="none">
					<FileIcon kind={node.kind} mime={node.mime} size={32} />
					<p>{m.viewer_unavailable()}</p>
				</div>
			{/if}

			{#if items.length > 1}
				<button class="nav next" aria-label={m.viewer_next()} onclick={() => go(1)}>
					<ChevronRight size={24} aria-hidden="true" />
				</button>
			{/if}
		</div>
	{/if}
</dialog>

<style>
	.viewer {
		width: 100vw;
		height: 100dvh;
		max-width: none;
		max-height: none;
		margin: 0;
		padding: 0;
		border: 0;
		background: color-mix(in srgb, var(--color-bg) 92%, black);
		color: var(--color-text);
	}
	.viewer[open] {
		display: flex;
		flex-direction: column;
		animation: fade var(--duration-base) var(--ease-standard);
	}
	.viewer::backdrop {
		background: var(--color-overlay);
	}
	@keyframes fade {
		from {
			opacity: 0;
		}
	}
	header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-4);
		padding: var(--space-2) var(--space-3) var(--space-2) var(--space-5);
		border-bottom: 1px solid var(--color-border);
		background: var(--color-surface);
	}
	.title {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		min-width: 0;
	}
	.ids {
		display: grid;
		min-width: 0;
	}
	h2 {
		font-size: var(--text-md);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.ids span {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
	}
	.tools {
		display: flex;
		gap: var(--space-1);
	}
	.icon-btn {
		display: grid;
		place-items: center;
		width: 2.75rem;
		height: 2.75rem;
		border: 0;
		border-radius: var(--radius-md);
		background: transparent;
		color: var(--color-text);
		cursor: pointer;
	}
	.icon-btn:hover {
		background: var(--color-surface-sunken);
	}
	.stage {
		position: relative;
		flex: 1;
		min-height: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: var(--space-5) var(--space-8);
	}
	img,
	video {
		max-width: 100%;
		max-height: 100%;
		object-fit: contain;
		border-radius: var(--radius-md);
		box-shadow: var(--shadow-lg);
	}
	audio {
		width: min(32rem, 100%);
	}
	iframe {
		width: min(60rem, 100%);
		height: 100%;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-md);
		background: white;
	}
	.text {
		width: min(60rem, 100%);
		height: 100%;
		overflow: auto;
		padding: var(--space-5);
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-md);
	}
	pre {
		margin: 0;
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		line-height: var(--leading-normal);
		white-space: pre-wrap;
		overflow-wrap: anywhere;
	}
	.none {
		display: grid;
		justify-items: center;
		gap: var(--space-3);
		color: var(--color-text-muted);
	}
	.muted {
		color: var(--color-text-muted);
	}
	.nav {
		position: absolute;
		top: 50%;
		transform: translateY(-50%);
		display: grid;
		place-items: center;
		width: 3rem;
		height: 3rem;
		border: 1px solid var(--color-border);
		border-radius: var(--radius-full);
		background: var(--color-surface-raised);
		color: var(--color-text);
		box-shadow: var(--shadow-md);
		cursor: pointer;
	}
	.nav:hover {
		background: var(--color-surface-sunken);
	}
	.prev {
		left: var(--space-4);
	}
	.next {
		right: var(--space-4);
	}
	@media (max-width: 600px) {
		.stage {
			padding: var(--space-3);
		}
		.nav {
			top: auto;
			bottom: var(--space-4);
			transform: none;
		}
	}
</style>
