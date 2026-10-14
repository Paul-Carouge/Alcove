<script lang="ts">
	import type { Tag } from './tags.svelte.js';

	let { tag, size = 'sm' }: { tag: Pick<Tag, 'name' | 'color'>; size?: 'sm' | 'md' } = $props();
</script>

<span class="chip {tag.color} {size}">{tag.name}</span>

<style>
	.chip {
		display: inline-flex;
		align-items: center;
		max-width: 12rem;
		overflow: hidden;
		border-radius: var(--radius-full);
		font-weight: var(--weight-medium);
		line-height: 1.5;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.sm {
		padding: 0 var(--space-2);
		font-size: var(--text-xs);
	}
	.md {
		padding: 2px var(--space-3);
		font-size: var(--text-sm);
	}
	.gray {
		background: var(--color-tag-gray-bg);
		color: var(--color-tag-gray);
	}
	.red {
		background: var(--color-tag-red-bg);
		color: var(--color-tag-red);
	}
	.orange {
		background: var(--color-tag-orange-bg);
		color: var(--color-tag-orange);
	}
	.yellow {
		background: var(--color-tag-yellow-bg);
		color: var(--color-tag-yellow);
	}
	.green {
		background: var(--color-tag-green-bg);
		color: var(--color-tag-green);
	}
	.teal {
		background: var(--color-tag-teal-bg);
		color: var(--color-tag-teal);
	}
	.blue {
		background: var(--color-tag-blue-bg);
		color: var(--color-tag-blue);
	}
	.violet {
		background: var(--color-tag-violet-bg);
		color: var(--color-tag-violet);
	}
	.pink {
		background: var(--color-tag-pink-bg);
		color: var(--color-tag-pink);
	}
</style>
