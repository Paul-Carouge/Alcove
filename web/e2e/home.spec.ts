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
	await page.getByRole('combobox', { name: 'Language' }).selectOption('fr');
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
