import { expect, test, type Page } from '@playwright/test';
import { USER } from './fixtures';

// 4x4 red PNG.
const PNG = Buffer.from(
	'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEklEQVR4nGP4z8DAwMDAxMDAAAAMAQEB6CFdlQAAAABJRU5ErkJggg==',
	'base64'
);

async function setup(page: Page) {
	await page.goto('/login');
	await page.getByLabel('Email').fill(USER.email);
	await page.getByLabel('Password').fill(USER.password);
	await page.getByRole('button', { name: 'Sign in' }).click();
	const folder = `Preview ${Date.now()}-${Math.floor(Math.random() * 1e6)}`;
	await page.getByRole('button', { name: 'New folder' }).click();
	const dialog = page.getByRole('dialog', { name: 'New folder' });
	await dialog.getByLabel('Folder name').fill(folder);
	await dialog.getByRole('button', { name: 'Create' }).click();
	await page.getByRole('link', { name: folder }).click();
	await expect(page.getByRole('heading', { name: folder, level: 1 })).toBeVisible();
	await page.locator('input[type=file]').setInputFiles([
		{ name: 'red.png', mimeType: 'image/png', buffer: PNG },
		{ name: 'readme.txt', mimeType: 'text/plain', buffer: Buffer.from('Hello preview!') }
	]);
	await expect(page.getByRole('row', { name: /readme\.txt/ })).toBeVisible();
	await expect(page.getByRole('row', { name: /red\.png/ })).toBeVisible();
}

const loaded = (img: ReturnType<Page['locator']>) =>
	img.evaluate((el: HTMLImageElement) => el.complete && el.naturalWidth > 0);

test('thumbnails load and the viewer shows images and text', async ({ page }) => {
	await setup(page);

	const thumb = page.getByRole('row', { name: /red\.png/ }).locator('img');
	await expect.poll(() => loaded(thumb)).toBe(true);

	await page.getByRole('button', { name: 'red.png', exact: true }).click();
	const viewer = page.getByRole('dialog', { name: 'red.png' });
	await expect(viewer).toBeVisible();
	await expect.poll(() => loaded(viewer.getByRole('img', { name: 'red.png' }))).toBe(true);
	await expect(viewer).toContainText('2 of 2'); // natural order: readme.txt, red.png

	await page.keyboard.press('ArrowRight'); // wraps around
	const textViewer = page.getByRole('dialog', { name: 'readme.txt' });
	await expect(textViewer.locator('pre')).toHaveText('Hello preview!');

	await page.keyboard.press('Escape');
	await expect(textViewer).toBeHidden();
});

test('grid layout shows tiles and is remembered', async ({ page }) => {
	await setup(page);
	await page.getByRole('radio', { name: 'Grid view' }).click();
	const grid = page.locator('ul.grid');
	await expect(grid.getByRole('listitem')).toHaveCount(2);
	await expect.poll(() => loaded(grid.locator('img').first())).toBe(true);

	await page.reload();
	await expect(page.getByRole('radio', { name: 'Grid view' })).toHaveAttribute(
		'aria-checked',
		'true'
	);
	await page.getByRole('radio', { name: 'List view' }).click();
	await expect(page.getByRole('table')).toBeVisible();
});
