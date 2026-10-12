import { getSystem, type SystemInfo } from './api.js';

/** System/update status for administrators (loaded once per session). */
class SystemStore {
	current = $state<SystemInfo | null>(null);

	async load() {
		try {
			this.current = await getSystem();
		} catch {
			this.current = null;
		}
	}

	set(info: SystemInfo) {
		this.current = info;
	}
}

export const system = new SystemStore();
