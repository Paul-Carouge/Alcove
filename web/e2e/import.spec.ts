import { expect, test } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import { IMPORT_USER } from './fixtures';

const fixture = (name: string) => fileURLToPath(new URL(`./fixtures/${name}`, import.meta.url));

// A small Takeout export: scan.jpg (no EXIF date) in "Photos from 2013" and in the album "Summer trip",
// with Google's date (14 July 2013), place, description and favorite in its JSON sidecar.
test('import a Google Takeout archive: dates, album and description are restored', async ({
	page
}) => {
	test.setTimeout(90_000);
	await page.goto('/login');
	await page.getByLabel('Email').fill(IMPORT_USER.email);
	await page.getByLabel('Password').fill(IMPORT_USER.password);
	await page.getByRole('button', { name: 'Sign in' }).click();
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();

	await page.getByRole('navigation').getByRole('link', { name: 'Photos', exact: true }).click();
	await page.getByRole('link', { name: 'Import' }).click();
	await expect(
		page.getByRole('heading', { name: 'Import from Google Photos', level: 1 })
	).toBeVisible();
	await expect(page.getByRole('link', { name: /Open Google Takeout/ })).toHaveAttribute(
		'href',
		'https://takeout.google.com/'
	);
	await page.getByRole('button', { name: 'I have my archives' }).click();

	await page.locator('input[type=file]').setInputFiles(fixture('takeout-small.zip'));
	await expect(page.getByText('Uploaded')).toBeVisible();
	await page.getByRole('button', { name: 'Start the import' }).click();

	await expect(page.getByRole('heading', { name: '4. Report' })).toBeVisible({ timeout: 30_000 });
	await expect(page.getByText('Import finished.')).toBeVisible();
	const count = (label: string) =>
		page
			.locator('.counts div')
			.filter({ has: page.getByText(label, { exact: true }) })
			.locator('dd');
	await expect(count('Imported')).toHaveText('1');
	await expect(count('Already present')).toHaveText('1');
	await expect(count('Albums')).toHaveText('1');

	// The timeline shows the photo at Google's date, not at the upload date.
	await page.getByRole('link', { name: 'View photos' }).click();
	await expect(page.getByRole('heading', { name: 'July 2013', level: 2 })).toBeVisible();
	await page.getByRole('button', { name: 'Open scan.jpg' }).click();
	const viewer = page.getByRole('dialog', { name: 'scan.jpg' });
	const info = viewer.getByRole('complementary', { name: 'Details' });
	if (!(await info.isVisible())) await viewer.getByRole('button', { name: 'Show details' }).click();
	await expect(info).toContainText("Grandma's garden");
	await expect(info).toContainText('2013');
	await page.keyboard.press('Escape');

	// The album folder became an album, holding the same (single) file.
	await page.getByRole('navigation').getByRole('link', { name: 'Albums', exact: true }).click();
	const card = page.getByRole('link', { name: /Summer trip/ });
	await expect(card).toContainText('1 item');
	await card.click();
	await expect(page.getByRole('button', { name: 'Open scan.jpg' })).toHaveCount(1);
});
