import type { RecordModel } from 'pocketbase';

/** A record of the `nodes` collection (see server/migrations). */
export interface DriveNode extends RecordModel {
	owner: string;
	parent: string;
	name: string;
	kind: 'file' | 'folder';
	blob: string;
	size: number;
	mime: string;
	sha256: string;
	trashed_at: string;
	created: string;
	updated: string;
}
