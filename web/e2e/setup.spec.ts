import { expect, test } from '@playwright/test';
import { SETUP_PORT, SETUP_TOKEN } from '../playwright.config';

// Runs against the second instance, which has no administrator yet.
test.use({ baseURL: `http://127.0.0.1:${SETUP_PORT}` });

test('first-run wizard creates the administrator and signs in', async ({ page }) => {
	// Any page leads to the wizard while setup is required.
	await page.goto('/');
	await expect(page).toHaveURL(/\/setup$/);
	await expect(page.getByRole('heading', { name: 'Welcome to Alcove' })).toBeVisible();

	await page.getByLabel('Setup token').fill('not-the-right-token');
	await page.getByRole('button', { name: 'Continue' }).click();
	await expect(page.getByText('This setup token is not valid.')).toBeVisible();

	await page.getByLabel('Setup token').fill(SETUP_TOKEN);
	await page.getByRole('button', { name: 'Continue' }).click();

	await expect(page.getByRole('heading', { name: 'Create the administrator' })).toBeVisible();
	await page.getByLabel('Name').fill('Camille');
	await page.getByLabel('Email').fill('admin@setup.test');
	await page.getByLabel('Password', { exact: true }).fill('setup-password-123');
	await page.getByLabel('Confirm new password').fill('setup-password-123');
	await page.getByRole('button', { name: 'Continue' }).click();

	await expect(page.getByRole('heading', { name: 'Email (optional)' })).toBeVisible();
	await page.getByRole('button', { name: 'Continue' }).click();

	await expect(page.getByRole('heading', { name: 'Ready to go' })).toBeVisible();
	await expect(page.getByText('Local disk, writable')).toBeVisible();
	await page.getByRole('button', { name: 'Finish setup' }).click();

	// Signed straight into the app with the new account.
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();

	// The wizard is closed afterwards, and the admin console accepts the same credentials.
	const res = await page.request.post('/api/collections/_superusers/auth-with-password', {
		data: { identity: 'admin@setup.test', password: 'setup-password-123' }
	});
	expect(res.status()).toBe(200);
	await page.goto('/setup');
	await expect(page.getByText('This server is already set up.')).toBeVisible();
});
