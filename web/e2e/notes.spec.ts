import AxeBuilder from '@axe-core/playwright';
import { expect, test, type Page } from '@playwright/test';
import { NOTES_USER } from './fixtures';

async function signIn(page: Page) {
	await page.goto('/login');
	await page.getByLabel('Email').fill(NOTES_USER.email);
	await page.getByLabel('Password').fill(NOTES_USER.password);
	await page.getByRole('button', { name: 'Sign in' }).click();
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();
}

test.describe.configure({ mode: 'serial' });

test('a note is created, autosaved, kept after a reload and synced live', async ({
	page,
	browser
}) => {
	await signIn(page);
	await page.getByRole('navigation').getByRole('link', { name: 'Notes', exact: true }).click();
	await expect(page.getByRole('heading', { name: 'No notes yet' })).toBeVisible();

	await page.getByRole('button', { name: 'New note' }).first().click();
	const title = page.getByRole('textbox', { name: 'Title' });
	await expect(title).toBeFocused();
	await title.fill('Shopping');
	await page
		.getByRole('textbox', { name: 'Text of the note' })
		.fill('# Market\n- [ ] apples\n- bread');
	await expect(page.getByRole('status').filter({ hasText: 'Saved' })).toBeVisible();
	const list = page.getByRole('region', { name: 'Your notes' });
	await expect(list.getByRole('button', { name: /Shopping/ })).toContainText('Market');

	const { violations } = await new AxeBuilder({ page })
		.withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
		.analyze();
	expect(violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target).join(' ')}`)).toEqual([]);

	// Saved on the server: a reload opens the same note with its text.
	await page.reload();
	await expect(page.getByRole('textbox', { name: 'Title' })).toHaveValue('Shopping');
	await expect(page.getByRole('textbox', { name: 'Text of the note' })).toHaveValue(
		'# Market\n- [ ] apples\n- bread'
	);
	await page.getByRole('radio', { name: 'Preview' }).click();
	await expect(page.getByRole('heading', { name: 'Market' })).toBeVisible();
	await expect(page.getByRole('checkbox')).toBeDisabled();

	// Another device (here a second session) sees edits without reloading.
	const other = await browser.newPage();
	await signIn(other);
	await other.goto(page.url());
	await expect(other.getByRole('textbox', { name: 'Title' })).toHaveValue('Shopping');
	await page.getByRole('radio', { name: 'Write' }).click();
	await page.getByRole('textbox', { name: 'Title' }).fill('Shopping list');
	await expect(other.getByRole('textbox', { name: 'Title' })).toHaveValue('Shopping list', {
		timeout: 10_000
	});
	await other.close();

	// Pinned, found by the global search, then moved to the trash.
	await page.getByRole('button', { name: 'Pin', exact: true }).click();
	await expect(page.getByRole('button', { name: 'Unpin' })).toBeVisible();
	await page.getByRole('search').getByRole('searchbox').fill('apples');
	await page.getByRole('search').getByRole('searchbox').press('Enter');
	await page.getByRole('link', { name: 'Shopping list' }).click();
	await expect(page.getByRole('textbox', { name: 'Title' })).toHaveValue('Shopping list');
	await page.getByRole('button', { name: 'Move to trash' }).click();
	await expect(page.getByRole('status').filter({ hasText: 'No notes yet' })).toBeVisible();
	await page.getByRole('radio', { name: 'Trash' }).click();
	await expect(list.getByRole('button', { name: /Shopping list/ })).toBeVisible();
});

test('edits that failed to save survive switching notes and are sent on retry', async ({
	page
}) => {
	await signIn(page);
	await page.goto('/notes');
	const list = page.getByRole('region', { name: 'Your notes' });
	const title = page.getByRole('textbox', { name: 'Title' });
	const body = page.getByRole('textbox', { name: 'Text of the note' });

	await page.getByRole('button', { name: 'New note' }).first().click();
	await expect(title).toBeFocused();
	await title.fill('Second');
	await expect(page.getByRole('status').filter({ hasText: 'Saved' })).toBeVisible();
	await page.getByRole('button', { name: 'New note' }).first().click();
	await expect(list.getByRole('button', { name: /Untitled/ })).toHaveAttribute(
		'aria-current',
		'true'
	);
	await expect(title).toHaveValue('');
	await title.fill('First');
	await expect(page.getByRole('status').filter({ hasText: 'Saved' })).toBeVisible();

	// Offline: the save fails.
	await page.route('**/api/collections/notes/records/*', (route) =>
		route.request().method() === 'PATCH' ? route.abort() : route.continue()
	);
	await body.fill('typed while offline');
	await expect(page.getByRole('button', { name: /Not saved/ })).toBeVisible();

	// Away and back: the text and the failed state are still there.
	await list.getByRole('button', { name: /Second/ }).click();
	await expect(title).toHaveValue('Second');
	await list.getByRole('button', { name: /First/ }).click();
	await expect(body).toHaveValue('typed while offline');
	await expect(page.getByRole('button', { name: /Not saved/ })).toBeVisible();

	// Back online: retry sends it.
	await page.unroute('**/api/collections/notes/records/*');
	await page.getByRole('button', { name: /Not saved/ }).click();
	await expect(page.getByRole('status').filter({ hasText: 'Saved' })).toBeVisible();
	await page.reload();
	await expect(body).toHaveValue('typed while offline');
});
