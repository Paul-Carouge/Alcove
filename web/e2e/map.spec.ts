import { expect, test, type Page } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import { ADMIN_USER, MAP_USER } from './fixtures';

const fixture = (name: string) => fileURLToPath(new URL(`./fixtures/${name}`, import.meta.url));

async function signIn(page: Page, user: { email: string; password: string }) {
	await page.goto('/login');
	await page.getByLabel('Email').fill(user.email);
	await page.getByLabel('Password').fill(user.password);
	await page.getByRole('button', { name: 'Sign in' }).click();
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();
}

// The tiles switch is server-wide: the admin test must not run while the basemap test does.
test.describe.configure({ mode: 'serial' });

test('the map shows located photos with the built-in basemap only', async ({ page, baseURL }) => {
	const origin = new URL(baseURL!).origin;
	const outside: string[] = [];
	const errors: string[] = [];
	page.on('request', (r) => {
		if (!r.url().startsWith(origin) && !r.url().startsWith('data:')) outside.push(r.url());
	});
	page.on('console', (msg) => msg.type() === 'error' && errors.push(msg.text()));

	await signIn(page, MAP_USER);
	await page
		.locator('input[type=file]')
		.setInputFiles([fixture('lyon.jpg'), fixture('winter.jpg')]);
	await expect(page.getByRole('region', { name: 'Uploads' })).toContainText('2 of 2 uploaded');
	await page.getByRole('navigation').getByRole('link', { name: 'Photos', exact: true }).click();
	// Locations are read when the photo is processed: wait for its thumbnail.
	await expect
		.poll(() =>
			page
				.getByRole('button', { name: 'Open lyon.jpg' })
				.locator('img')
				.evaluate((i: HTMLImageElement) => i.naturalWidth)
				.catch(() => 0)
		)
		.toBeGreaterThan(0);
	await page.getByRole('link', { name: 'Map' }).click();

	await expect(page.getByRole('heading', { name: 'Map', level: 1 })).toBeVisible();
	// The location is read when the photo is processed, which may finish after its thumbnail shows.
	await expect(async () => {
		await page.reload();
		await expect(page.getByText('1 photo with a location')).toBeVisible({ timeout: 1000 });
	}).toPass({ timeout: 20_000 });
	const map = page.getByRole('region', { name: 'Map' });
	await expect(map.locator('path.leaflet-interactive, svg path').first()).toBeAttached();
	await expect(map.getByText('Natural Earth')).toBeVisible();

	await map.getByRole('button', { name: 'Photo' }).click();
	await expect(page.getByRole('dialog', { name: 'lyon.jpg' })).toBeVisible();
	await page.keyboard.press('Escape');

	expect(outside, 'requests leaving the server').toEqual([]);
	expect(errors.filter((e) => /Content Security Policy|Refused/.test(e))).toEqual([]);
});

test('administrators can enable OpenStreetMap tiles', async ({ page, request, baseURL }) => {
	await signIn(page, ADMIN_USER);
	await page.goto('/admin/system');
	const toggle = page.getByRole('switch', { name: 'Detailed map tiles from OpenStreetMap' });
	await expect(toggle).not.toBeChecked();
	await toggle.check();
	await expect(toggle).toBeChecked();
	const csp = async () =>
		(await request.get(`${baseURL}/photos/map`)).headers()['content-security-policy'] ?? '';
	expect(await csp()).toContain('https://tile.openstreetmap.org');
	await toggle.uncheck();
	await expect(toggle).not.toBeChecked();
	expect(await csp()).not.toContain('openstreetmap');
});
