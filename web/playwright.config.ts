import { defineConfig, devices } from '@playwright/test';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// E2E tests run against the real server binary with the web UI embedded
// (`make build` first). Each run uses a fresh, throwaway data directory.
const port = 8097;
const dataDir = mkdtempSync(join(tmpdir(), 'alcove-e2e-'));
process.env.ALCOVE_E2E_DATA_DIR = dataDir;

// A second, brand-new instance (no administrator) for the first-run wizard.
export const SETUP_PORT = 8098;
export const SETUP_TOKEN = 'e2e-setup-token-0123456789';
const setupDataDir = mkdtempSync(join(tmpdir(), 'alcove-e2e-setup-'));

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
		// Zero-duration transitions (our tokens honor it): axe must not sample mid-fade colors.
		reducedMotion: 'reduce',
		// Optional override of the browser binary. Prefer Playwright's own
		// Chromium (`pnpm exec playwright install chromium`): browsers with
		// built-in content blockers (e.g. Helium) make navigation tests flaky.
		launchOptions: process.env.ALCOVE_E2E_BROWSER
			? { executablePath: process.env.ALCOVE_E2E_BROWSER }
			: {}
	},
	projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
	webServer: [
		{
			command: 'node e2e/fake-releases.mjs',
			url: 'http://127.0.0.1:8099/repos/Paul-Carouge/Alcove/releases/latest',
			reuseExistingServer: false
		},
		{
			command: `../server/bin/alcove serve --http=127.0.0.1:${port} --dir=${dataDir}`,
			url: `http://127.0.0.1:${port}/health`,
			env: { ALCOVE_UPDATE_URL: 'http://127.0.0.1:8099' },
			reuseExistingServer: false,
			stdout: 'ignore'
		},
		{
			command: `../server/bin/alcove serve --http=127.0.0.1:${SETUP_PORT} --dir=${setupDataDir}`,
			url: `http://127.0.0.1:${SETUP_PORT}/health`,
			env: { ALCOVE_SETUP_TOKEN: SETUP_TOKEN },
			reuseExistingServer: false,
			stdout: 'ignore'
		}
	]
});
