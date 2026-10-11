export type ThemeMode = 'system' | 'light' | 'dark';

const KEY = 'alcove-theme';

function read(): ThemeMode {
	try {
		const v = localStorage.getItem(KEY);
		return v === 'light' || v === 'dark' ? v : 'system';
	} catch {
		return 'system';
	}
}

/** Light/dark/system preference, persisted per browser, applied via data-theme. */
class Theme {
	mode = $state<ThemeMode>(typeof window === 'undefined' ? 'system' : read());

	set(mode: ThemeMode) {
		this.mode = mode;
		try {
			if (mode === 'system') localStorage.removeItem(KEY);
			else localStorage.setItem(KEY, mode);
		} catch {
			// Storage unavailable (private mode): keep the choice for this session only.
		}
		this.apply();
	}

	apply() {
		const root = document.documentElement;
		if (this.mode === 'system') root.removeAttribute('data-theme');
		else root.dataset.theme = this.mode;
	}
}

export const theme = new Theme();
