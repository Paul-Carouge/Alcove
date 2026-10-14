import { expect, test } from '@playwright/test';
import { QUOTA_USER } from './fixtures';

const file = (name: string, bytes: number) => ({
	name,
	mimeType: 'text/plain',
	buffer: Buffer.alloc(bytes, 'a')
});

test('storage meter, quota rejection and almost-full warning', async ({ page }) => {
	await page.goto('/login');
	await page.getByLabel('Email').fill(QUOTA_USER.email);
	await page.getByLabel('Password').fill(QUOTA_USER.password);
	await page.getByRole('button', { name: 'Sign in' }).click();

	const meter = page.getByRole('region', { name: 'Storage' });
	await expect(meter).toContainText('0\u00a0B of 100\u00a0B used');

	const input = page.locator('input[type=file]');
	await input.setInputFiles(file('sixty.txt', 60));
	await expect(page.getByRole('row', { name: /sixty\.txt/ })).toBeVisible();
	await expect(meter).toContainText('60\u00a0B of 100\u00a0B used');

	await input.setInputFiles(file('too-big.txt', 60));
	const panel = page.getByRole('region', { name: 'Uploads' });
	await expect(panel.getByRole('listitem').filter({ hasText: 'too-big.txt' })).toContainText(
		'Not enough space'
	);
	await expect(page.getByRole('row', { name: /too-big\.txt/ })).toBeHidden();

	await input.setInputFiles(file('fits.txt', 35));
	await expect(page.getByRole('row', { name: /fits\.txt/ })).toBeVisible();
	await expect(meter).toContainText('95\u00a0B of 100\u00a0B used');
	await expect(meter).toContainText('Almost full');
});
