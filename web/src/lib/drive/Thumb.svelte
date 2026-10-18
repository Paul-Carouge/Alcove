<script lang="ts">
	import FileIcon from './FileIcon.svelte';
	import {
		fileToken,
		hasThumbnail,
		mediaOf,
		mediaUrl,
		prefersMedia,
		thumbUrl,
		type ThumbSize
	} from './files.js';
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
		const current = node;
		const useMedia = prefersMedia(current);
		if (!useMedia && !hasThumbnail(current)) return;
		// The media worker's JPEGs first: they cover HEIC and videos and are upright.
		Promise.all([fileToken(), useMedia ? mediaOf(current) : null]).then(([token, media]) => {
			if (current !== node) return;
			if (media) src = mediaUrl(media, size === '1600x0' ? 'preview' : 'thumb', token);
			else if (hasThumbnail(current)) src = thumbUrl(current, size, token);
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
