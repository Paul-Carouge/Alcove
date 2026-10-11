import { SvelteSet } from 'svelte/reactivity';

/** Selection of rows with shift-click ranges over the visible order. */
export class Selection {
	ids = new SvelteSet<string>();
	#anchor: string | null = null;

	get size() {
		return this.ids.size;
	}

	has(id: string) {
		return this.ids.has(id);
	}

	/** Toggles one id, or selects the range from the last anchor when `range`. */
	toggle(id: string, order: string[], range = false) {
		if (range && this.#anchor && order.includes(this.#anchor)) {
			const [a, b] = [order.indexOf(this.#anchor), order.indexOf(id)].sort((x, y) => x - y);
			for (const i of order.slice(a, b + 1)) this.ids.add(i);
		} else if (this.ids.has(id)) {
			this.ids.delete(id);
		} else {
			this.ids.add(id);
		}
		this.#anchor = id;
	}

	setAll(order: string[], on: boolean) {
		this.ids.clear();
		if (on) for (const id of order) this.ids.add(id);
		this.#anchor = null;
	}

	/** Drops ids that are no longer visible (moved, trashed, deleted). */
	retain(order: string[]) {
		for (const id of [...this.ids]) if (!order.includes(id)) this.ids.delete(id);
	}

	clear() {
		this.setAll([], false);
	}
}
