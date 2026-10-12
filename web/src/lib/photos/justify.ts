export interface JustifiedRow<T> {
	items: T[];
	height: number;
}

/**
 * Packs items into rows that fill `width` exactly (like Google Photos /
 * Flickr): each row grows until its height at full width drops below
 * `target`. The last row keeps the target height instead of stretching.
 */
export function justify<T>(
	items: T[],
	ratio: (item: T) => number,
	width: number,
	target: number,
	gap: number
): JustifiedRow<T>[] {
	if (width <= 0) return [];
	const rows: JustifiedRow<T>[] = [];
	let row: T[] = [];
	let sum = 0;
	for (const item of items) {
		const r = clampRatio(ratio(item));
		row.push(item);
		sum += r;
		const height = (width - gap * (row.length - 1)) / sum;
		if (height <= target) {
			rows.push({ items: row, height });
			row = [];
			sum = 0;
		}
	}
	if (row.length) {
		const fullHeight = (width - gap * (row.length - 1)) / sum;
		rows.push({ items: row, height: Math.min(target, fullHeight) });
	}
	return rows;
}

/** Very wide or tall images would make unusable rows. */
export const clampRatio = (r: number) =>
	Number.isFinite(r) && r > 0 ? Math.min(3, Math.max(0.4, r)) : 1;
