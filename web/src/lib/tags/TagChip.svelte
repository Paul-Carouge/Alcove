<script lang="ts">
	import type { Tag } from './tags.svelte.js';

	let { tag, size = 'sm' }: { tag: Pick<Tag, 'name' | 'color'>; size?: 'sm' | 'md' } = $props();
</script>

<span class="chip {tag.color} {size}">{tag.name}</span>

<style>
	.chip {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
		max-width: 12rem;
		overflow: hidden;
		border-radius: var(--radius-full);
		font-weight: var(--weight-medium);
		line-height: 1.5;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	/* A small dot of the tag colour: the tone reads even at a glance. */
	.chip::before {
		content: '';
		flex: none;
		width: 0.375rem;
		height: 0.375rem;
		border-radius: var(--radius-full);
		background: currentColor;
		opacity: 0.8;
	}
	.sm {
		padding: 0 var(--space-2);
		font-size: var(--text-xs);
	}
	.md {
		padding: var(--space-0) var(--space-3);
		min-height: 1.75rem;
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
