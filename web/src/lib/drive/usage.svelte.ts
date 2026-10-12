import { createApiClient, type components } from '@alcove/api-spec';
import { pb } from '#lib/pb.js';
import { onNodeChange } from './live.js';

export type Usage = components['schemas']['Usage'];

/** Share of the quota at which the meter turns into a warning. */
export const WARN_RATIO = 0.9;

/** Signed-in user's storage, refreshed after drive changes (debounced). */
class UsageStore {
	current = $state<Usage | null>(null);
	#timer: ReturnType<typeof setTimeout> | undefined;
	#stop: (() => void) | null = null;

	get ratio() {
		const u = this.current;
		return u && u.quota > 0 ? Math.min(1, u.used / u.quota) : 0;
	}

	async refresh() {
		const { data } = await createApiClient(window.location.origin).GET('/api/v1/me/usage', {
			headers: { Authorization: pb.authStore.token }
		});
		if (data) this.current = data;
	}

	start() {
		this.refresh();
		this.#stop ??= onNodeChange(() => {
			clearTimeout(this.#timer);
			this.#timer = setTimeout(() => this.refresh(), 800);
		});
	}

	stop() {
		this.#stop?.();
		this.#stop = null;
		clearTimeout(this.#timer);
		this.current = null;
	}
}

export const usage = new UsageStore();
