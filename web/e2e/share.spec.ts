import { expect, test, type Browser, type Page } from '@playwright/test';
import { USER } from './fixtures';

async function signIn(page: Page) {
	await page.goto('/login');
	await page.getByLabel('Email').fill(USER.email);
	await page.getByLabel('Password').fill(USER.password);
	await page.getByRole('button', { name: 'Sign in' }).click();
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();
}

const unique = (p: string) => `${p} ${Date.now()}-${Math.floor(Math.random() * 1e6)}`;

async function folderWith(page: Page, files: Record<string, string>) {
	const folder = unique('Share');
	await page.getByRole('button', { name: 'New folder' }).click();
	const d = page.getByRole('dialog', { name: 'New folder' });
	await d.getByLabel('Folder name').fill(folder);
	await d.getByRole('button', { name: 'Create' }).click();
	await page.getByRole('link', { name: folder }).click();
	await expect(page.getByRole('heading', { name: folder, level: 1 })).toBeVisible();
	await page.locator('input[type=file]').setInputFiles(
		Object.entries(files).map(([name, body]) => ({
			name,
			mimeType: 'text/plain',
			buffer: Buffer.from(body)
		}))
	);
	for (const name of Object.keys(files)) {
		await expect(
			page.getByRole('row', { name: new RegExp(name.replace('.', '\\.')) })
		).toBeVisible();
	}
	return folder;
}

async function createLink(page: Page, item: string, opts: { password?: string } = {}) {
	await page.getByRole('button', { name: `Actions for ${item}` }).click();
	await page.getByRole('menuitem', { name: 'Share…' }).click();
	const dialog = page.getByRole('dialog', { name: `Share “${item}”` });
	await dialog.getByText('Never').click();
	if (opts.password) {
		await dialog.getByLabel('Protect with a password').check();
		await dialog.getByLabel('Password', { exact: true }).fill(opts.password);
	}
	await dialog.getByRole('button', { name: 'Create link' }).click();
	const link = await dialog.getByLabel('Public link').inputValue();
	expect(link).toMatch(/\/s\/[A-Za-z0-9_-]{43}$/);
	await dialog.getByRole('button', { name: 'Done' }).click();
	return link;
}

/** A visitor without an account. */
async function visitor(browser: Browser) {
	const context = await browser.newContext({ locale: 'en-US' });
	return { page: await context.newPage(), close: () => context.close() };
}

async function downloadText(page: Page, trigger: () => Promise<void>) {
	const [download] = await Promise.all([page.waitForEvent('download'), trigger()]);
	const chunks: Buffer[] = [];
	for await (const c of await download.createReadStream()) chunks.push(c as Buffer);
	return { name: download.suggestedFilename(), body: Buffer.concat(chunks).toString() };
}

test('share a file and download it without an account', async ({ page, browser }) => {
	await signIn(page);
	await folderWith(page, { 'public.txt': 'hello visitor' });
	const link = await createLink(page, 'public.txt');

	const v = await visitor(browser);
	await v.page.goto(link);
	await expect(v.page.getByText('Shared with you')).toBeVisible();
	await expect(v.page.getByRole('heading', { name: 'public.txt' })).toBeVisible();
	const file = await downloadText(v.page, () =>
		v.page.getByRole('link', { name: 'Download' }).click()
	);
	expect(file).toEqual({ name: 'public.txt', body: 'hello visitor' });
	await v.close();
});

test('password-protected link', async ({ page, browser }) => {
	await signIn(page);
	await folderWith(page, { 'secret.txt': 'classified' });
	const link = await createLink(page, 'secret.txt', { password: 'open sesame' });

	const v = await visitor(browser);
	await v.page.goto(link);
	await expect(v.page.getByRole('heading', { name: 'This link is protected' })).toBeVisible();
	await v.page.getByLabel('Password').fill('wrong');
	await v.page.getByRole('button', { name: 'Open' }).click();
	await expect(v.page.getByText('Wrong password.')).toBeVisible();
	await v.page.getByLabel('Password').fill('open sesame');
	await v.page.getByRole('button', { name: 'Open' }).click();
	await expect(v.page.getByRole('heading', { name: 'secret.txt' })).toBeVisible();
	const file = await downloadText(v.page, () =>
		v.page.getByRole('link', { name: 'Download' }).click()
	);
	expect(file.body).toBe('classified');
	await v.close();
});

test('revoking a link from the Shared page disables it', async ({ page, browser }) => {
	await signIn(page);
	await folderWith(page, { 'temp.txt': 'soon gone' });
	const link = await createLink(page, 'temp.txt');

	await page.getByRole('link', { name: 'Shared', exact: true }).click();
	await expect(page.getByRole('heading', { name: 'Shared links' })).toBeVisible();
	await page
		.getByRole('row', { name: /temp\.txt/ })
		.getByRole('button', { name: /Revoke link/ })
		.click();
	await expect(page.getByRole('row', { name: /temp\.txt/ })).toBeHidden();

	const v = await visitor(browser);
	await v.page.goto(link);
	await expect(v.page.getByText('This link does not exist or has been revoked.')).toBeVisible();
	await v.close();
});

test('folder links can be browsed but not escaped', async ({ page, browser }) => {
	await signIn(page);
	const folder = await folderWith(page, { 'top.txt': 'top' });
	await page.getByRole('button', { name: 'New folder' }).click();
	const d = page.getByRole('dialog', { name: 'New folder' });
	await d.getByLabel('Folder name').fill('Inner');
	await d.getByRole('button', { name: 'Create' }).click();
	await page.getByRole('link', { name: 'Inner' }).click();
	await expect(page.getByRole('heading', { name: 'Inner', level: 1 })).toBeVisible();
	await page
		.locator('input[type=file]')
		.setInputFiles({ name: 'deep.txt', mimeType: 'text/plain', buffer: Buffer.from('deep') });
	await expect(page.getByRole('row', { name: /deep\.txt/ })).toBeVisible();
	await page
		.getByRole('navigation', { name: 'Folder path' })
		.getByRole('link', { name: 'My files' })
		.click();
	const link = await createLink(page, folder);

	const v = await visitor(browser);
	await v.page.goto(link);
	await expect(v.page.getByRole('heading', { name: folder })).toBeVisible();
	await v.page.getByRole('button', { name: 'Inner' }).click();
	await expect(v.page.getByText('deep.txt')).toBeVisible();
	const file = await downloadText(v.page, () =>
		v.page.getByRole('link', { name: 'Download deep.txt' }).click()
	);
	expect(file.body).toBe('deep');

	await v.page.goto(`${link}?folder=doesnotexist`);
	await expect(v.page.getByText('This link does not exist or has been revoked.')).toBeVisible();
	await v.close();
});
