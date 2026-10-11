import { expect, test, type ConsoleMessage } from '@playwright/test';

test('home page boots under the real CSP and shows server status', async ({ page }) => {
	const errors: string[] = [];
	page.on('console', (msg: ConsoleMessage) => {
		if (msg.type() === 'error') errors.push(msg.text());
	});
	page.on('pageerror', (err) => errors.push(err.message));

	const response = await page.goto('/');
	expect(response?.headers()['content-security-policy']).toContain("script-src 'self' 'sha256-");

	await expect(page.getByRole('heading', { level: 1 })).toHaveText('Alcove');
	await expect(page.getByText('Connected')).toBeVisible();
	await expect(page.getByText(/first launch/i)).toBeVisible(); // fresh data dir: no admin yet
	expect(errors, errors.join('\n')).toEqual([]);
});

test('follows the browser language (French)', async ({ browser }) => {
	const context = await browser.newContext({ locale: 'fr-FR' });
	const page = await context.newPage();
	await page.goto('/');
	await expect(page.getByText('Connecté')).toBeVisible();
	await expect(page.locator('html')).toHaveAttribute('lang', 'fr');
	await context.close();
});

test('language can be switched and is remembered', async ({ page }) => {
	await page.goto('/');
	// Switching locale reloads the document (Paraglide); assertions retry across it.
	await page.getByRole('combobox', { name: 'Language' }).selectOption('fr');
	await expect(page.locator('html')).toHaveAttribute('lang', 'fr');
	await expect(page.getByText('Connecté')).toBeVisible();
	await page.reload();
	await expect(page.getByText('Connecté')).toBeVisible();
});

test('unknown routes are served by the SPA and show a translated 404', async ({ page }) => {
	const response = await page.goto('/some/deep/link');
	expect(response?.status()).toBe(200);
	await expect(page.getByRole('heading', { level: 1 })).toHaveText('Page not found');
	await page.getByRole('link', { name: 'Back to home' }).click();
	await expect(page.getByText('Connected')).toBeVisible();
});
