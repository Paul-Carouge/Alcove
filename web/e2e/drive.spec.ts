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
	await expect(row).toContainText('21\u00a0B');
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

async function uploadInto(page: Page, folder: string, file: string, content: string) {
	await newFolder(page, folder);
	await page.getByRole('link', { name: folder }).click();
	await expect(page.getByRole('heading', { name: folder, level: 1 })).toBeVisible();
	await page.locator('input[type=file]').setInputFiles({
		name: file,
		mimeType: 'text/plain',
		buffer: Buffer.from(content)
	});
	await expect(page.getByRole('row', { name: new RegExp(file.replace('.', '\\.')) })).toBeVisible();
}

test('rename with the keyboard and download a file', async ({ page }) => {
	await signIn(page);
	await uploadInto(page, unique('Actions'), 'draft.txt', 'content to download');

	// Menu button pattern: Enter opens, arrows move, Enter selects.
	await page.getByRole('button', { name: 'Actions for draft.txt' }).focus();
	await page.keyboard.press('Enter');
	await expect(page.getByRole('menuitem', { name: 'Download' })).toBeFocused();
	await page.keyboard.press('ArrowDown'); // Share…
	await page.keyboard.press('ArrowDown'); // Rename
	await expect(page.getByRole('menuitem', { name: 'Rename' })).toBeFocused();
	await page.keyboard.press('Enter');

	const dialog = page.getByRole('dialog', { name: 'Rename' });
	await dialog.getByLabel('New name').fill('final.txt');
	await dialog.getByRole('button', { name: 'Save' }).click();
	await expect(page.getByRole('row', { name: /final\.txt/ })).toBeVisible();

	await page.getByRole('button', { name: 'Actions for final.txt' }).click();
	const [download] = await Promise.all([
		page.waitForEvent('download'),
		page.getByRole('menuitem', { name: 'Download' }).click()
	]);
	expect(download.suggestedFilename()).toBe('final.txt');
	const body = await download.createReadStream().then(async (s) => {
		const chunks: Buffer[] = [];
		for await (const c of s) chunks.push(c as Buffer);
		return Buffer.concat(chunks).toString();
	});
	expect(body).toBe('content to download');
});

test('trash, restore and delete forever', async ({ page }) => {
	await signIn(page);
	const folder = unique('Trash');
	await uploadInto(page, folder, 'old.txt', 'bye');

	await page.getByRole('button', { name: 'Actions for old.txt' }).click();
	await page.getByRole('menuitem', { name: 'Move to trash' }).click();
	await expect(page.getByRole('row', { name: /old\.txt/ })).toBeHidden();

	await page.getByRole('link', { name: 'Trash', exact: true }).click();
	await expect(page.getByRole('heading', { name: 'Trash', level: 1 })).toBeVisible();
	await page.getByRole('button', { name: 'Actions for old.txt' }).click();
	await page.getByRole('menuitem', { name: 'Restore' }).click();
	await expect(page.getByRole('row', { name: /old\.txt/ })).toBeHidden();

	// Back in its folder, then trashed again and deleted for good.
	await page.getByRole('link', { name: 'Files', exact: true }).click();
	await page.getByRole('link', { name: folder }).click();
	await page.getByRole('button', { name: 'Actions for old.txt' }).click();
	await page.getByRole('menuitem', { name: 'Move to trash' }).click();
	await page.getByRole('link', { name: 'Trash', exact: true }).click();
	await page.getByRole('button', { name: 'Actions for old.txt' }).click();
	await page.getByRole('menuitem', { name: 'Delete forever' }).click();
	const confirm = page.getByRole('dialog', { name: 'Delete forever?' });
	await confirm.getByRole('button', { name: 'Delete forever' }).click();
	await expect(confirm).toBeHidden();
	await expect(page.getByRole('row', { name: /old\.txt/ })).toBeHidden();
});

async function openFolderWithFiles(page: Page, folder: string, files: string[]) {
	await newFolder(page, folder);
	await page.getByRole('link', { name: folder }).click();
	await expect(page.getByRole('heading', { name: folder, level: 1 })).toBeVisible();
	await page
		.locator('input[type=file]')
		.setInputFiles(
			files.map((name) => ({ name, mimeType: 'text/plain', buffer: Buffer.from(name) }))
		);
	for (const name of files)
		await expect(page.getByRole('row', { name: new RegExp(name) })).toBeVisible();
}

test('select a range with shift and move it into a folder', async ({ page }) => {
	await signIn(page);
	await openFolderWithFiles(page, unique('Sel'), ['a1.txt', 'a2.txt', 'a3.txt']);
	await newFolder(page, 'Target');

	await page.getByRole('checkbox', { name: 'Select a1.txt' }).click();
	await page.getByRole('checkbox', { name: 'Select a3.txt' }).click({ modifiers: ['Shift'] });
	const bar = page.getByRole('toolbar', { name: '3 selected' });
	await expect(bar).toBeVisible();
	for (const name of ['a1.txt', 'a2.txt', 'a3.txt']) {
		await expect(page.getByRole('checkbox', { name: `Select ${name}` })).toBeChecked();
	}

	await bar.getByRole('button', { name: 'Move to…' }).click();
	const dialog = page.getByRole('dialog', { name: 'Move 3 items' });
	await dialog.getByRole('button', { name: 'Target' }).click();
	await dialog.getByRole('button', { name: 'Move here' }).click();

	for (const name of ['a1.txt', 'a2.txt', 'a3.txt']) {
		await expect(page.getByRole('row', { name: new RegExp(name) })).toBeHidden();
	}
	await expect(bar).toBeHidden();
	await page.getByRole('link', { name: 'Target' }).click();
	await expect(page.getByRole('row', { name: /a2\.txt/ })).toBeVisible();
});

test('drag a row onto a folder to move it', async ({ page }) => {
	await signIn(page);
	await openFolderWithFiles(page, unique('Drag'), ['moveme.txt']);
	await newFolder(page, 'Inbox');

	await page
		.getByRole('row', { name: /moveme\.txt/ })
		.dragTo(page.getByRole('row', { name: /Inbox/ }));
	await expect(page.getByRole('row', { name: /moveme\.txt/ })).toBeHidden();
	await page.getByRole('link', { name: 'Inbox' }).click();
	await expect(page.getByRole('row', { name: /moveme\.txt/ })).toBeVisible();
});

test('select all and move everything to the trash', async ({ page }) => {
	await signIn(page);
	await openFolderWithFiles(page, unique('Bulk'), ['x1.txt', 'x2.txt']);

	await page.getByRole('checkbox', { name: 'Select all' }).check();
	await page
		.getByRole('toolbar', { name: '2 selected' })
		.getByRole('button', { name: 'Move to trash' })
		.click();
	await expect(page.getByText('This folder is empty')).toBeVisible();
});

test('a folder downloads as a ZIP', async ({ page }) => {
	await signIn(page);
	const folder = unique('Zip');
	await uploadInto(page, folder, 'inside.txt', 'zipped');
	await page.getByRole('link', { name: 'Files', exact: true }).click();
	await page.getByRole('button', { name: `Actions for ${folder}` }).click();
	const [download] = await Promise.all([
		page.waitForEvent('download'),
		page.getByRole('menuitem', { name: 'Download (ZIP)' }).click()
	]);
	expect(download.suggestedFilename()).toBe(`${folder}.zip`);
	const bytes = await download.createReadStream().then(async (s) => {
		const chunks: Buffer[] = [];
		for await (const c of s) chunks.push(c as Buffer);
		return Buffer.concat(chunks);
	});
	// A ZIP whose entry is the folder's file.
	expect(bytes.subarray(0, 2).toString()).toBe('PK');
	expect(bytes.includes(Buffer.from(`${folder}/inside.txt`))).toBe(true);
});

test('empty files and names with emoji upload', async ({ page }) => {
	await signIn(page);
	const folder = unique('Edge');
	await newFolder(page, folder);
	await page.getByRole('link', { name: folder }).click();
	await expect(page.getByRole('heading', { name: folder, level: 1 })).toBeVisible();
	await page.locator('input[type=file]').setInputFiles([
		{ name: 'vide.txt', mimeType: 'text/plain', buffer: Buffer.alloc(0) },
		{ name: 'Été 🌞.txt', mimeType: 'text/plain', buffer: Buffer.from('soleil') }
	]);
	await expect(page.getByRole('region', { name: 'Uploads' })).toContainText('2 of 2 uploaded');
	await expect(page.getByRole('row', { name: /vide\.txt/ })).toBeVisible();
	await expect(page.getByRole('row', { name: /Été 🌞\.txt/ })).toBeVisible();
});
