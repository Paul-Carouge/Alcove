/** Groups points that are close on screen (grid clustering), for the photo map. */
export interface Point<T> {
	x: number;
	y: number;
	item: T;
}

export interface Cluster<T> {
	x: number;
	y: number;
	items: T[];
}

export function cluster<T>(points: Point<T>[], cell: number): Cluster<T>[] {
	const cells = new Map<string, Cluster<T> & { sx: number; sy: number }>();
	for (const p of points) {
		const key = `${Math.floor(p.x / cell)}:${Math.floor(p.y / cell)}`;
		let c = cells.get(key);
		if (!c) {
			c = { x: 0, y: 0, sx: 0, sy: 0, items: [] };
			cells.set(key, c);
		}
		c.items.push(p.item);
		c.sx += p.x;
		c.sy += p.y;
	}
	return [...cells.values()].map(({ sx, sy, items }) => ({
		x: sx / items.length,
		y: sy / items.length,
		items
	}));
}
