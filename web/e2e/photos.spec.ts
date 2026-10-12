import { expect, test, type Page } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import { PHOTO_USER } from './fixtures';

const fixture = (name: string) => fileURLToPath(new URL(`./fixtures/${name}`, import.meta.url));

async function signIn(page: Page) {
	await page.goto('/login');
	await page.getByLabel('Email').fill(PHOTO_USER.email);
	await page.getByLabel('Password').fill(PHOTO_USER.password);
	await page.getByRole('button', { name: 'Sign in' }).click();
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();
}

// One serial flow: the timeline shows every photo of the account.
test.describe.configure({ mode: 'serial' });

test('photos from Files appear in a timeline grouped by month', async ({ page }) => {
	await signIn(page);
	await page.getByRole('navigation').getByRole('link', { name: 'Photos' }).click();
	await expect(page.getByRole('heading', { name: 'Photos', level: 1 })).toBeVisible();
	await expect(page.getByRole('heading', { name: 'No photos yet' })).toBeVisible();

	// Uploading from Files is enough; the timeline updates live.
	await page.getByRole('navigation').getByRole('link', { name: 'Files' }).click();
	await page
		.locator('input[type=file]')
		.setInputFiles(['lyon.jpg', 'winter.jpg', 'scan.jpg', 'clip.mp4'].map(fixture));
	await expect(page.getByRole('region', { name: 'Uploads' })).toContainText('4 of 4 uploaded');

	await page.getByRole('navigation').getByRole('link', { name: 'Photos' }).click();
	await expect(page.getByRole('heading', { name: 'June 2025', level: 2 })).toBeVisible();
	await expect(page.getByRole('heading', { name: 'March 2025', level: 2 })).toBeVisible();
	await expect(page.getByRole('heading', { name: 'December 2024', level: 2 })).toBeVisible();

	// Newest first: the photo without EXIF date (dated by upload) comes before 2025.
	const headings = await page.locator('.month h2').allTextContents();
	expect(headings.indexOf('June 2025')).toBeLessThan(headings.indexOf('March 2025'));
	expect(headings.indexOf('March 2025')).toBeLessThan(headings.indexOf('December 2024'));
	expect(headings.indexOf('June 2025')).toBeGreaterThan(0);
	expect(headings).toHaveLength(4);

	// Thumbnails load once the derivatives are ready.
	const lyon = page.getByRole('button', { name: 'Open lyon.jpg' });
	await expect(lyon.locator('img')).toHaveJSProperty('complete', true);
	await expect
		.poll(() => lyon.locator('img').evaluate((i: HTMLImageElement) => i.naturalHeight))
		.toBe(360);
	await expect(page.getByRole('button', { name: 'Open clip.mp4' })).toContainText('0:03');
});

test('the viewer shows details and plays videos', async ({ page }) => {
	await signIn(page);
	await page.getByRole('navigation').getByRole('link', { name: 'Photos' }).click();
	await page.getByRole('button', { name: 'Open lyon.jpg' }).click();

	const viewer = page.getByRole('dialog', { name: 'lyon.jpg' });
	await expect(viewer.getByRole('img', { name: 'lyon.jpg' })).toBeVisible();
	const info = viewer.getByRole('complementary', { name: 'Details' });
	await expect(info).toContainText('2025');
	await expect(info).toContainText('Apple iPhone 16');
	await expect(info.getByRole('link', { name: 'Open in OpenStreetMap' })).toHaveAttribute(
		'href',
		/openstreetmap\.org\/\?mlat=45\.7/
	);

	// Arrow keys walk the timeline (newest first): June 2025 → March 2025.
	await page.keyboard.press('ArrowRight');
	const video = page.getByRole('dialog', { name: 'clip.mp4' }).locator('video');
	await expect(video).toBeVisible();
	await expect.poll(() => video.evaluate((v: HTMLVideoElement) => v.readyState)).toBeGreaterThan(0);
	await expect(page.getByRole('dialog', { name: 'clip.mp4' })).toContainText('Duration');

	await page.keyboard.press('Escape');
	await expect(page.getByRole('dialog')).toBeHidden();
});

test('favorites are toggled from the grid and filtered', async ({ page }) => {
	await signIn(page);
	await page.getByRole('navigation').getByRole('link', { name: 'Photos' }).click();
	const heart = page.getByRole('button', { name: 'Add winter.jpg to favorites' });
	await heart.click();
	await expect(
		page.getByRole('button', { name: 'Remove winter.jpg from favorites' })
	).toHaveAttribute('aria-pressed', 'true');

	await page.getByRole('radio', { name: 'Favorites' }).click();
	await expect(page.getByRole('button', { name: 'Open winter.jpg' })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Open lyon.jpg' })).toHaveCount(0);

	await page.getByRole('radio', { name: 'Videos' }).click();
	await expect(page.getByRole('button', { name: 'Open clip.mp4' })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Open winter.jpg' })).toHaveCount(0);

	// Persisted on the server.
	await page.reload();
	await page.getByRole('radio', { name: 'Favorites' }).click();
	await expect(page.getByRole('button', { name: 'Open winter.jpg' })).toBeVisible();
});
