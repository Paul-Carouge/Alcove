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

	// A colour per family, from the tag palette (contrast checked in the design tokens).
	const tone = $derived.by(() => {
		if (kind === 'folder') return 'folder';
		if (mime.startsWith('image/')) return 'green';
		if (mime.startsWith('video/')) return 'pink';
		if (mime.startsWith('audio/')) return 'violet';
		if (/zip|tar|gzip|7z|rar|compressed/.test(mime)) return 'yellow';
		if (/spreadsheet|excel|csv/.test(mime)) return 'teal';
		if (/pdf/.test(mime)) return 'red';
		if (mime.startsWith('text/') || /document|msword|rtf/.test(mime)) return 'blue';
		return 'gray';
	});

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

<span
	class="icon {tone}"
	aria-hidden="true"
	style:--icon-box={size > 24 ? `${Math.round(size * 1.8)}px` : undefined}
	><Icon {size} strokeWidth={1.75} /></span
>

<style>
	.icon {
		display: inline-grid;
		place-items: center;
		flex: none;
		width: var(--icon-box, 2.5rem);
		height: var(--icon-box, 2.5rem);
		border-radius: var(--radius-md);
		background: var(--color-surface-sunken);
		color: var(--color-text-muted);
	}
	.folder {
		background: var(--color-accent-subtle);
		color: var(--color-accent);
	}
	.green {
		background: var(--color-tag-green-bg);
		color: var(--color-tag-green);
	}
	.pink {
		background: var(--color-tag-pink-bg);
		color: var(--color-tag-pink);
	}
	.violet {
		background: var(--color-tag-violet-bg);
		color: var(--color-tag-violet);
	}
	.yellow {
		background: var(--color-tag-yellow-bg);
		color: var(--color-tag-yellow);
	}
	.teal {
		background: var(--color-tag-teal-bg);
		color: var(--color-tag-teal);
	}
	.red {
		background: var(--color-tag-red-bg);
		color: var(--color-tag-red);
	}
	.blue {
		background: var(--color-tag-blue-bg);
		color: var(--color-tag-blue);
	}
</style>
