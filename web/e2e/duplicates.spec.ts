import { expect, test, type Page } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { DUP_USER } from './fixtures';

const fixture = (name: string) => fileURLToPath(new URL(`./fixtures/${name}`, import.meta.url));

async function signIn(page: Page) {
	await page.goto('/login');
	await page.getByLabel('Email').fill(DUP_USER.email);
	await page.getByLabel('Password').fill(DUP_USER.password);
	await page.getByRole('button', { name: 'Sign in' }).click();
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();
}

const nav = (page: Page, name: string) =>
	page.getByRole('navigation').getByRole('link', { name, exact: true }).click();
const tiles = (page: Page) => page.getByRole('button', { name: /^Open / });

test.describe.configure({ mode: 'serial' });

test('filters narrow the timeline by year, camera and location', async ({ page }) => {
	await signIn(page);
	const file = (path: string, name = path) => ({
		name,
		mimeType: 'image/jpeg',
		buffer: readFileSync(fixture(path))
	});
	// harbor-small.jpg is harbor.jpg resized: a textured picture, unlike the gradient fixtures.
	await page
		.locator('input[type=file]')
		.setInputFiles([
			file('harbor.jpg'),
			file('harbor.jpg', 'harbor copy.jpg'),
			file('harbor-small.jpg'),
			file('lyon.jpg'),
			file('winter.jpg')
		]);
	await expect(page.getByRole('region', { name: 'Uploads' })).toContainText('5 of 5 uploaded');

	await nav(page, 'Photos');
	await expect(tiles(page)).toHaveCount(5);
	await page.getByRole('button', { name: 'Filters' }).click();
	const filters = page.getByRole('group', { name: 'Filters' });
	await filters.getByLabel('Year').selectOption('2024');
	await expect(tiles(page)).toHaveCount(1);
	await expect(page.getByRole('button', { name: 'Open winter.jpg' })).toBeVisible();

	await filters.getByLabel('Year').selectOption('');
	await filters.getByLabel(/With a location/).check();
	await expect(tiles(page)).toHaveCount(4);
	await expect(page.getByRole('button', { name: 'Open winter.jpg' })).toHaveCount(0);

	await filters.getByLabel(/With a location/).uncheck();
	await filters.getByLabel('Camera').selectOption({ label: 'Fujifilm X100V (1)' });
	await expect(tiles(page)).toHaveCount(1);

	await filters.getByRole('button', { name: 'Reset filters' }).click();
	await expect(tiles(page)).toHaveCount(5);
});

test('duplicates are grouped and the extra copies go to the trash', async ({ page }) => {
	await signIn(page);
	await nav(page, 'Photos');
	await page.getByRole('link', { name: 'Duplicates' }).click();
	await expect(page.getByRole('heading', { name: 'Duplicates', level: 1 })).toBeVisible();

	// One group: the photo, its identical copy and its resized version. The others stay out.
	const group = page.getByRole('listitem').filter({ has: page.getByRole('heading', { level: 2 }) });
	await expect(group).toHaveCount(1);
	await expect(group).toContainText('Similar photos');
	await expect(group.getByRole('button', { name: /lyon|winter/ })).toHaveCount(0);
	// The best copy is kept, the two others are marked.
	await expect(
		group.getByRole('button', { name: 'harbor-small.jpg, will be moved to the trash' })
	).toBeVisible();
	await expect(group.getByRole('button', { name: /, kept$/ })).toHaveCount(1);

	await group.getByRole('button', { name: 'Move 2 to trash' }).click();
	await expect(page.getByRole('status')).toContainText('2 items moved to the trash');
	await expect(page.getByRole('heading', { name: 'No duplicates found' })).toBeVisible();

	await nav(page, 'Trash');
	await expect(page.getByRole('row', { name: /harbor-small\.jpg/ })).toBeVisible();
});
