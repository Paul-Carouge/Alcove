import type { RecordModel } from 'pocketbase';
import { pb } from '#lib/pb.js';

export const TAG_COLORS = [
	'gray',
	'red',
	'orange',
	'yellow',
	'green',
	'teal',
	'blue',
	'violet',
	'pink'
] as const;
export type TagColor = (typeof TAG_COLORS)[number];

/** A record of the `tags` collection: a per-user label on files and folders. */
export interface Tag extends RecordModel {
	owner: string;
	name: string;
	color: TagColor;
}

const tagsCol = () => pb.collection<Tag>('tags');
const byName = (a: Tag, b: Tag) => a.name.localeCompare(b.name, undefined, { sensitivity: 'base' });

/** The signed-in user's tags, kept current by realtime updates while loaded. */
class TagStore {
	items = $state<Tag[]>([]);
	loaded = $state(false);
	#unsub: (() => void) | null = null;

	byId = $derived(new Map(this.items.map((t) => [t.id, t])));
	#user = pb.authStore.record?.id ?? '';

	constructor() {
		// Another account (or none): the tags belong to someone else.
		pb.authStore.onChange((_token, record) => {
			const id = record?.id ?? '';
			if (id !== this.#user) {
				this.#user = id;
				this.reset();
			}
		});
	}

	async load() {
		if (this.loaded) return;
		this.items = (await tagsCol().getFullList({ batch: 500 })).sort(byName);
		this.loaded = true;
		if (!this.#unsub) {
			const stop = await tagsCol().subscribe('*', (e) => {
				const rest = this.items.filter((t) => t.id !== e.record.id);
				this.items = e.action === 'delete' ? rest : [...rest, e.record].sort(byName);
			});
			this.#unsub = () => void stop();
		}
	}

	async create(name: string, color: TagColor): Promise<Tag> {
		const tag = await tagsCol().create({
			owner: pb.authStore.record?.id,
			name: name.trim(),
			color
		});
		if (!this.items.some((t) => t.id === tag.id)) this.items = [...this.items, tag].sort(byName);
		return tag;
	}

	async update(id: string, data: Partial<Pick<Tag, 'name' | 'color'>>) {
		const tag = await tagsCol().update(id, data);
		this.items = this.items.map((t) => (t.id === id ? tag : t)).sort(byName);
	}

	async remove(id: string) {
		await tagsCol().delete(id);
		this.items = this.items.filter((t) => t.id !== id);
	}

	/** Forgets everything (on sign-out). */
	reset() {
		this.#unsub?.();
		this.#unsub = null;
		this.items = [];
		this.loaded = false;
	}
}

export const tags = new TagStore();

/** Sets the tags of a file or folder. */
export function setNodeTags(nodeId: string, tagIds: string[]) {
	return pb.collection('nodes').update(nodeId, { tags: tagIds });
}

/** The next colour for a new tag, cycling through the palette. */
export const nextColor = (count: number): TagColor => TAG_COLORS[(count + 6) % TAG_COLORS.length]!;
