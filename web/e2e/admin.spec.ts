import { expect, test, type Page } from '@playwright/test';
import { ADMIN_USER, USER } from './fixtures';

async function signIn(page: Page, who: { email: string; password: string }) {
	await page.goto('/login');
	await page.getByLabel('Email').fill(who.email);
	await page.getByLabel('Password').fill(who.password);
	await page.getByRole('button', { name: 'Sign in' }).click();
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();
}

test('administrators see available updates and how to install them', async ({ page }) => {
	await signIn(page, ADMIN_USER);
	await page.getByRole('button', { name: 'Account menu' }).click();
	await page.getByRole('link', { name: 'System' }).click();
	await expect(page.getByRole('heading', { name: 'System', level: 1 })).toBeVisible();
	await expect(page.getByText('Started manually')).toBeVisible();

	await page.getByRole('button', { name: 'Check now' }).click();
	await expect(page.getByText('Version 99.0.0 is available.')).toBeVisible();
	// Notes are rendered as Markdown, with HTML escaped.
	await expect(page.locator('.notes strong')).toHaveText('Time travel');
	await expect(page.locator('.notes')).toContainText('<script>alert(1)</script>');
	// Started by hand: no button, the command to run instead.
	await expect(page.getByRole('button', { name: /Update to/ })).toHaveCount(0);
	await expect(page.getByText('sudo alcove update')).toBeVisible();

	// The banner appears across the app and can be dismissed for this version.
	await page.getByRole('link', { name: 'Files', exact: true }).click();
	const banner = page.getByRole('status').filter({ hasText: '99.0.0 is available' });
	await expect(banner).toBeVisible();
	await banner.getByRole('button', { name: 'Later' }).click();
	await expect(banner).toBeHidden();
	await page.reload();
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();
	await expect(page.getByText('99.0.0 is available.')).toBeHidden();
});

test('regular users have no access to system administration', async ({ page }) => {
	await signIn(page, USER);
	await page.getByRole('button', { name: 'Account menu' }).click();
	await expect(page.getByRole('link', { name: 'System' })).toHaveCount(0);
	await page.goto('/admin/system');
	await expect(page.getByText('This page is for administrators.')).toBeVisible();
	const token = await page.evaluate(
		() => JSON.parse(localStorage.getItem('pocketbase_auth') ?? '{}').token
	);
	const res = await page.request.get('/api/v1/admin/system', { headers: { Authorization: token } });
	expect(res.status()).toBe(403);
});
