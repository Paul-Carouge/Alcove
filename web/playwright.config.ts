import { defineConfig, devices } from '@playwright/test';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// E2E tests run against the real server binary with the web UI embedded
// (`make build` first). Each run uses a fresh, throwaway data directory.
const port = 8097;
const dataDir = mkdtempSync(join(tmpdir(), 'alcove-e2e-'));
process.env.ALCOVE_E2E_DATA_DIR = dataDir;

export default defineConfig({
	testDir: 'e2e',
	globalSetup: './e2e/global-setup.ts',
	fullyParallel: true,
	forbidOnly: !!process.env.CI,
	retries: process.env.CI ? 1 : 0,
	reporter: process.env.CI ? 'github' : 'list',
	use: {
		baseURL: `http://127.0.0.1:${port}`,
		trace: 'retain-on-failure',
		// Optional override of the browser binary. Prefer Playwright's own
		// Chromium (`pnpm exec playwright install chromium`): browsers with
		// built-in content blockers (e.g. Helium) make navigation tests flaky.
		launchOptions: process.env.ALCOVE_E2E_BROWSER
			? { executablePath: process.env.ALCOVE_E2E_BROWSER }
			: {}
	},
	projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
	webServer: {
		command: `../server/bin/alcove serve --http=127.0.0.1:${port} --dir=${dataDir}`,
		url: `http://127.0.0.1:${port}/health`,
		reuseExistingServer: false,
		stdout: 'ignore'
	}
});
