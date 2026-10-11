import { expect, test, type Page } from '@playwright/test';
import { USER } from './fixtures';

async function signIn(page: Page) {
	await page.goto('/login');
	await page.getByLabel('Email').fill(USER.email);
	await page.getByLabel('Password').fill(USER.password);
	await page.getByRole('button', { name: 'Sign in' }).click();
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();
}

// Tests share one account: each uses its own uniquely named folder.
const unique = (prefix: string) => `${prefix} ${Date.now()}-${Math.floor(Math.random() * 1e6)}`;

async function newFolder(page: Page, name: string) {
	await page.getByRole('button', { name: 'New folder' }).click();
	const dialog = page.getByRole('dialog', { name: 'New folder' });
	await dialog.getByLabel('Folder name').fill(name);
	await dialog.getByRole('button', { name: 'Create' }).click();
	await expect(dialog).toBeHidden();
}

test('create a folder, open it, upload a file into it', async ({ page }) => {
	await signIn(page);
	const folder = unique('Projects');
	await newFolder(page, folder);

	await page.getByRole('link', { name: folder }).click();
	await expect(page.getByRole('heading', { name: folder, level: 1 })).toBeVisible();
	await expect(page.getByText('This folder is empty')).toBeVisible();

	await page.locator('input[type=file]').setInputFiles({
		name: 'notes.txt',
		mimeType: 'text/plain',
		buffer: Buffer.from('hello from playwright')
	});

	const row = page.getByRole('row', { name: /notes\.txt/ });
	await expect(row).toBeVisible();
	await expect(row).toContainText('21 byte');
	await expect(page.getByRole('region', { name: 'Uploads' })).toContainText('1 of 1 uploaded');

	// Breadcrumbs lead back to the root, where the folder is listed.
	await page
		.getByRole('navigation', { name: 'Folder path' })
		.getByRole('link', { name: 'My files' })
		.click();
	await expect(page.getByRole('link', { name: folder })).toBeVisible();
});

test('duplicate folder names are rejected with a clear message', async ({ page }) => {
	await signIn(page);
	const folder = unique('Dup');
	await newFolder(page, folder);
	await page.getByRole('button', { name: 'New folder' }).click();
	const dialog = page.getByRole('dialog', { name: 'New folder' });
	await dialog.getByLabel('Folder name').fill(folder.toUpperCase());
	await dialog.getByRole('button', { name: 'Create' }).click();
	await expect(dialog.getByText('An item with this name already exists here.')).toBeVisible();
	await dialog.getByRole('button', { name: 'Cancel' }).click();
	await expect(dialog).toBeHidden();
});

test('changes appear live in another tab', async ({ browser }) => {
	const context = await browser.newContext();
	const [a, b] = [await context.newPage(), await context.newPage()];
	await signIn(a);
	await b.goto('/');
	await expect(b.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();

	const folder = unique('Live');
	await newFolder(a, folder);
	await expect(b.getByRole('link', { name: folder })).toBeVisible();
	await context.close();
});

test('unknown folders show a not-found message', async ({ page }) => {
	await signIn(page);
	await page.goto('/folders/doesnotexist123');
	await expect(page.getByText('This folder does not exist or was deleted.')).toBeVisible();
});
