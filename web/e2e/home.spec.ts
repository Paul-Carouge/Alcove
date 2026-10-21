import { expect, test, type ConsoleMessage } from '@playwright/test';

test('app boots under the real CSP without console errors', async ({ page }) => {
	const errors: string[] = [];
	page.on('console', (msg: ConsoleMessage) => {
		if (msg.type() === 'error') errors.push(msg.text());
	});
	page.on('pageerror', (err) => errors.push(err.message));

	const response = await page.goto('/login');
	expect(response?.headers()['content-security-policy']).toContain("script-src 'self' 'sha256-");
	await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
	expect(errors, errors.join('\n')).toEqual([]);
});

test('follows the browser language (French)', async ({ browser }) => {
	const context = await browser.newContext({ locale: 'fr-FR' });
	const page = await context.newPage();
	await page.goto('/login');
	await expect(page.getByRole('heading', { name: 'Connexion' })).toBeVisible();
	await expect(page.locator('html')).toHaveAttribute('lang', 'fr');
	await context.close();
});

test('language can be switched and is remembered', async ({ page }) => {
	await page.goto('/login');
	// Switching locale reloads the document (Paraglide); assertions retry across it.
	// Keyboard only, like a native select: open, go to the last language, choose it.
	const language = page.getByRole('combobox', { name: 'Language' });
	await language.focus();
	await page.keyboard.press('ArrowDown');
	await expect(page.getByRole('listbox', { name: 'Language' })).toBeVisible();
	await page.keyboard.press('End');
	await page.keyboard.press('Enter');
	await expect(page.locator('html')).toHaveAttribute('lang', 'fr');
	await expect(page.getByRole('heading', { name: 'Connexion' })).toBeVisible();
	await page.reload();
	await expect(page.getByRole('heading', { name: 'Connexion' })).toBeVisible();
});

test('unknown routes are served by the SPA and show a translated 404', async ({ page }) => {
	const response = await page.goto('/some/deep/link');
	expect(response?.status()).toBe(200);
	await expect(page.getByRole('heading', { level: 1 })).toHaveText('Page not found');
});

test('select commits the highlighted option on Tab, and Home/End open it', async ({ page }) => {
	await page.goto('/login');
	// WAI-ARIA select-only combobox: End on the closed field opens it on the last option.
	await page.getByRole('combobox', { name: 'Language' }).focus();
	await page.keyboard.press('End');
	await expect(page.getByRole('option', { name: 'Français' })).toHaveAttribute('data-highlighted');
	await page.keyboard.press('Tab');
	await expect(page.locator('html')).toHaveAttribute('lang', 'fr');
});
