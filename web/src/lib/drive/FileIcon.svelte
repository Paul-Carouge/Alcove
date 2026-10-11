<script lang="ts">
	import {
		File,
		FileArchive,
		FileAudio,
		FileCode,
		FileImage,
		FileSpreadsheet,
		FileText,
		FileVideo,
		Folder
	} from '@lucide/svelte';

	let { kind, mime = '', size = 20 }: { kind: string; mime?: string; size?: number } = $props();

	const Icon = $derived.by(() => {
		if (kind === 'folder') return Folder;
		if (mime.startsWith('image/')) return FileImage;
		if (mime.startsWith('video/')) return FileVideo;
		if (mime.startsWith('audio/')) return FileAudio;
		if (/zip|tar|gzip|7z|rar|compressed/.test(mime)) return FileArchive;
		if (/spreadsheet|excel|csv/.test(mime)) return FileSpreadsheet;
		if (/json|javascript|xml|x-sh|x-python|typescript/.test(mime)) return FileCode;
		if (mime.startsWith('text/') || /pdf|document|msword|rtf/.test(mime)) return FileText;
		return File;
	});
</script>

<span class="icon" class:folder={kind === 'folder'} aria-hidden="true"><Icon {size} /></span>

<style>
	.icon {
		display: inline-grid;
		place-items: center;
		flex: none;
		width: 2.25rem;
		height: 2.25rem;
		border-radius: var(--radius-md);
		background: var(--color-surface-sunken);
		color: var(--color-text-muted);
	}
	.folder {
		background: var(--color-accent-subtle);
		color: var(--color-accent);
	}
</style>
