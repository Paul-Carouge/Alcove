import type { RecordModel } from 'pocketbase';
import { pb } from '#lib/pb.js';

/** A record of the `notes` collection (ADR 0027). */
export interface Note extends RecordModel {
	owner: string;
	title: string;
	body: string;
	pinned: boolean;
	tags: string[];
	/** '' unless the note is in the trash. */
	trashed_at: string;
	created: string;
	updated: string;
}

export type NoteChanges = Partial<Pick<Note, 'title' | 'body' | 'pinned' | 'tags' | 'trashed_at'>>;

export const notesCol = () => pb.collection<Note>('notes');

export const createNote = () =>
	notesCol().create({ owner: pb.authStore.record?.id, title: '', body: '' });
export const updateNote = (id: string, data: NoteChanges) => notesCol().update(id, data);
export const deleteNote = (id: string) => notesCol().delete(id);

/** Notes (not in the trash) whose title or text contains the query, for the global search. */
export const searchNotes = (q: string) =>
	notesCol()
		.getList(1, 20, {
			filter: pb.filter('trashed_at = "" && (title ~ {:q} || body ~ {:q})', { q }),
			sort: '-pinned,-updated'
		})
		.then((res) => res.items);

/** PocketBase's date format ("2026-10-15 10:00:00.000Z"). */
// eslint-disable-next-line svelte/prefer-svelte-reactivity -- a one-off timestamp, not state
export const nowDate = () => new Date().toISOString().replace('T', ' ');

/** Pinned notes first, then the most recently updated. */
export function sortNotes<T extends Pick<Note, 'pinned' | 'updated'>>(notes: T[]): T[] {
	return [...notes].sort(
		(a, b) => Number(b.pinned) - Number(a.pinned) || b.updated.localeCompare(a.updated)
	);
}

const fold = (s: string) => s.normalize('NFD').replace(/\p{M}/gu, '').toLocaleLowerCase();

/**
 * Notes whose title or text contains every word typed (accents and case ignored), carrying the
 * tag when one is given.
 */
export function filterNotes<T extends Pick<Note, 'title' | 'body' | 'tags'>>(
	notes: T[],
	query: string,
	tag = ''
): T[] {
	const words = fold(query).split(/\s+/).filter(Boolean);
	return notes.filter((n) => {
		if (tag && !n.tags?.includes(tag)) return false;
		const text = fold(`${n.title}\n${n.body}`);
		return words.every((w) => text.includes(w));
	});
}

/** The first line of text of a note, without Markdown markers, for list rows. */
export function excerpt(body: string, max = 140): string {
	for (const line of body.split(/\r?\n/)) {
		if (/^\s*([-*_])(\s*\1){2,}\s*$/.test(line) || /^\s*```/.test(line)) continue;
		const text = line
			.replace(/^\s*(#{1,6}|[-*+]\s+\[[ xX]\]|[-*+]|\d+[.)]|>)\s*/, '')
			.replace(/[*_`]/g, '')
			.replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
			.trim();
		if (text) {
			return text.length > max ? text.slice(0, max - 1) + '…' : text;
		}
	}
	return '';
}

export type SaveState = 'idle' | 'pending' | 'saving' | 'saved' | 'error';

/**
 * Saves edits after a pause in typing. Changes made while a save is running are merged and sent
 * right after it, so saves never overlap and the last edit always wins.
 */
export class Autosave {
	state = $state<SaveState>('idle');
	#changes: NoteChanges = {};
	#inflight: NoteChanges = {};
	#timer: ReturnType<typeof setTimeout> | undefined;
	#running: Promise<void> | null = null;
	#cancelled = false;
	#save: (changes: NoteChanges) => Promise<unknown>;
	#delay: number;

	constructor(save: (changes: NoteChanges) => Promise<unknown>, delay = 800) {
		this.#save = save;
		this.#delay = delay;
	}

	/** True while some edits have not reached the server. */
	get dirty() {
		return this.state === 'pending' || this.state === 'saving' || this.state === 'error';
	}

	/** Edits not confirmed by the server yet (being sent, failed or waiting). */
	get unsaved(): NoteChanges {
		return { ...this.#inflight, ...this.#changes };
	}

	change(changes: NoteChanges) {
		if (this.#cancelled) return;
		this.#changes = { ...this.#changes, ...changes };
		this.state = 'pending';
		clearTimeout(this.#timer);
		this.#timer = setTimeout(() => void this.flush(), this.#delay);
	}

	/** Sends pending edits now (on blur, before switching notes). Check `state` for the outcome. */
	async flush(): Promise<void> {
		clearTimeout(this.#timer);
		if (this.#running) {
			await this.#running;
			if (Object.keys(this.#changes).length && (this.state as SaveState) !== 'error')
				return this.flush();
			return;
		}
		const changes = this.#changes;
		if (this.#cancelled || !Object.keys(changes).length) return;
		this.#changes = {};
		this.#inflight = changes;
		this.state = 'saving';
		this.#running = this.#save(changes).then(
			() => {
				this.#inflight = {};
				if (this.#cancelled) return;
				if (this.state === 'saving') this.state = 'saved';
			},
			() => {
				this.#inflight = {};
				if (this.#cancelled) return;
				// Keep them for the next attempt, under newer edits.
				this.#changes = { ...changes, ...this.#changes };
				this.state = 'error';
			}
		);
		await this.#running;
		this.#running = null;
		if (Object.keys(this.#changes).length && (this.state as SaveState) !== 'error')
			return this.flush();
	}

	/** Drops pending edits for good (the note was deleted). */
	cancel() {
		clearTimeout(this.#timer);
		this.#cancelled = true;
		this.#changes = {};
		this.state = 'idle';
	}
}
