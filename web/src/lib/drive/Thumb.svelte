<script lang="ts">
	import FileIcon from './FileIcon.svelte';
	import { fileToken, hasThumbnail, thumbUrl, type ThumbSize } from './files.js';
	import type { DriveNode } from './types.js';

	let {
		node,
		size = '96x96',
		iconSize = 20
	}: { node: DriveNode; size?: ThumbSize; iconSize?: number } = $props();

	let src = $state<string | null>(null);
	let failed = $state(false);

	$effect(() => {
		src = null;
		failed = false;
		if (!hasThumbnail(node)) return;
		const current = node;
		fileToken().then((token) => {
			if (current === node) src = thumbUrl(current, size, token);
		});
	});
</script>

{#if src && !failed}
	<img {src} alt="" loading="lazy" decoding="async" onerror={() => (failed = true)} />
{:else}
	<FileIcon kind={node.kind} mime={node.mime} size={iconSize} />
{/if}

<style>
	img {
		display: block;
		flex: none;
		width: 100%;
		height: 100%;
		object-fit: cover;
		border-radius: inherit;
		background: var(--color-surface-sunken);
	}
</style>
