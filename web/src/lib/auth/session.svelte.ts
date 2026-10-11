import type { RecordModel } from 'pocketbase';
import { pb } from '#lib/pb.js';

/** Reactive view of the PocketBase auth store. */
class Session {
	user = $state<RecordModel | null>(pb.authStore.record);

	constructor() {
		pb.authStore.onChange((_token, record) => {
			this.user = record;
		});
	}

	get isSignedIn() {
		return this.user !== null && pb.authStore.isValid;
	}

	/** Refreshes the token (and user record); signs out if it was revoked. */
	async refresh() {
		if (!pb.authStore.isValid) return;
		try {
			await pb.collection('users').authRefresh();
		} catch {
			pb.authStore.clear();
		}
	}

	signOut() {
		pb.authStore.clear();
	}
}

export const session = new Session();
