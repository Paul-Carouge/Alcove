import { loadServerStatus, type ServerStatus } from './status.js';

/** Server compatibility, checked once at app start and on retry. */
class ServerStatusStore {
	current = $state<ServerStatus | null>(null);

	async check() {
		this.current = null;
		this.current = await loadServerStatus(window.location.origin);
	}
}

export const serverStatus = new ServerStatusStore();
