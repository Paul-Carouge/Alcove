import { expect, test, type Page } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import { ADMIN_USER, DOC_USER } from './fixtures';

const fixture = (name: string) => fileURLToPath(new URL(`./fixtures/${name}`, import.meta.url));

async function signIn(page: Page, who: { email: string; password: string }) {
	await page.goto('/login');
	await page.getByLabel('Email').fill(who.email);
	await page.getByLabel('Password').fill(who.password);
	await page.getByRole('button', { name: 'Sign in' }).click();
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();
}

const nav = (page: Page, name: string) =>
	page.getByRole('navigation').getByRole('link', { name, exact: true }).click();

test.describe.configure({ mode: 'serial' });

test('the text of PDFs, text files and scans can be searched', async ({ page }) => {
	// OCR runs in the background, one document at a time.
	test.setTimeout(90_000);
	await signIn(page, DOC_USER);
	await nav(page, 'Documents');
	await expect(page.getByRole('heading', { name: 'No documents yet' })).toBeVisible();

	await nav(page, 'Files');
	await page
		.locator('input[type=file]')
		.setInputFiles([fixture('lease.pdf'), fixture('invoice.png'), fixture('harbor.jpg')]);
	await expect(page.getByRole('region', { name: 'Uploads' })).toContainText('3 of 3 uploaded');
	await page.getByRole('button', { name: 'Clear finished' }).click();

	// Read in the background; the page follows live.
	await nav(page, 'Documents');
	const list = page.getByRole('list').filter({ hasText: 'lease.pdf' });
	await expect(list.getByText('2 pages')).toBeVisible({ timeout: 20_000 });
	await expect(page.getByText(/read by OCR/)).toBeVisible({ timeout: 30_000 });
	await expect(page.getByRole('button', { name: 'invoice.png', exact: true })).toBeVisible();
	// A photo without text is not a document.
	await expect(page.getByRole('button', { name: 'harbor.jpg', exact: true })).toHaveCount(0);

	// The full text, ready to copy.
	await page
		.getByRole('listitem')
		.filter({ hasText: 'lease.pdf' })
		.getByRole('button', { name: 'Text' })
		.click();
	const dialog = page.getByRole('dialog', { name: 'lease.pdf' });
	await expect(dialog).toContainText('Le dépôt de garantie est de deux mois de loyer.');
	await dialog.getByRole('button', { name: 'Close' }).click();

	// Filters.
	await page.getByRole('radio', { name: 'Scans and screenshots' }).click();
	await expect(page.getByRole('button', { name: 'lease.pdf', exact: true })).toHaveCount(0);
	await expect(page.getByRole('button', { name: 'invoice.png', exact: true })).toBeVisible();

	// Search inside documents: accents and case ignored, words as prefixes.
	await page.getByRole('searchbox', { name: 'Search inside your documents' }).fill('DEPOT garant');
	await page.keyboard.press('Enter');
	await expect(page.getByRole('heading', { name: 'Search', level: 1 })).toBeVisible();
	await expect(page.getByText('1 inside a document')).toBeVisible();
	await expect(page.locator('mark').first()).toHaveText(/dépôt/);
	await expect(page.getByText('In the text')).toBeVisible();

	// The scan's text is searchable too.
	await page.getByRole('searchbox', { name: 'Search files and documents' }).fill('ALC-5521');
	await page.keyboard.press('Enter');
	await expect(page.getByRole('link', { name: 'invoice.png' })).toBeVisible();
});

test('administrators see the OCR tools on the System page', async ({ page }) => {
	await signIn(page, ADMIN_USER);
	await page.getByRole('button', { name: 'Account menu' }).click();
	await page.getByRole('link', { name: 'System' }).click();
	const card = page.getByRole('region', { name: 'Documents and OCR' });
	await expect(card.getByText(/^Tesseract \d/)).toBeVisible();
	const toggle = card.getByRole('switch', { name: 'Read the text of scans and screenshots (OCR)' });
	await expect(toggle).toBeChecked();
	await toggle.uncheck();
	await expect(toggle).not.toBeChecked();
	await page.reload();
	await expect(toggle).not.toBeChecked();
	await toggle.check();
	await expect(toggle).toBeChecked();
});

test('tags label files and filter documents', async ({ page }) => {
	await signIn(page, DOC_USER);
	// Tag a file from its menu in Files, creating the tag on the way.
	await page.getByRole('button', { name: 'Actions for lease.pdf' }).click();
	await page.getByRole('menuitem', { name: 'Tags' }).click();
	const dialog = page.getByRole('dialog', { name: 'Tags of “lease.pdf”' });
	await expect(dialog.getByText(/No tags yet/)).toBeVisible();
	await dialog.getByRole('textbox', { name: 'New tag' }).fill('Contrats');
	await dialog.getByRole('radio', { name: 'Green' }).first().click();
	await dialog.getByRole('button', { name: 'Add' }).click();
	await expect(dialog.getByRole('checkbox', { name: 'Contrats' })).toBeChecked();
	// Same name, other case: refused.
	await dialog.getByRole('textbox', { name: 'New tag' }).fill('contrats');
	await dialog.getByRole('button', { name: 'Add' }).click();
	await expect(dialog.getByText('You already have a tag with this name.')).toBeVisible();
	await dialog.getByRole('button', { name: 'Save' }).click();
	await expect(dialog).toBeHidden();
	await expect(page.getByRole('row', { name: /lease\.pdf/ }).getByText('Contrats')).toBeVisible();

	// Documents: filter by tag.
	await nav(page, 'Documents');
	const filter = page.getByRole('radiogroup', { name: 'Tag' });
	await filter.getByRole('radio', { name: 'Contrats' }).click();
	await expect(page.getByRole('button', { name: 'lease.pdf', exact: true })).toBeVisible();
	await expect(page.getByRole('button', { name: 'invoice.png', exact: true })).toHaveCount(0);

	// Rename the tag, then delete it: the file stays, untagged.
	await page.getByRole('button', { name: 'Tags of lease.pdf' }).click();
	const again = page.getByRole('dialog', { name: 'Tags of “lease.pdf”' });
	await again.getByRole('button', { name: 'Edit the tag Contrats' }).click();
	await again.getByRole('textbox', { name: 'Tag name' }).fill('Logement');
	await again.getByRole('button', { name: 'Save' }).first().click();
	await expect(again.getByRole('checkbox', { name: 'Logement' })).toBeChecked();
	await again.getByRole('button', { name: 'Edit the tag Logement' }).click();
	page.once('dialog', (d) => d.accept());
	await again.getByRole('button', { name: 'Delete' }).click();
	await expect(again.getByText(/No tags yet/)).toBeVisible();
	await again.getByRole('button', { name: 'Cancel' }).click();
	await expect(page.getByRole('radiogroup', { name: 'Tag' })).toHaveCount(0);
	await expect(page.getByRole('button', { name: 'invoice.png', exact: true })).toBeVisible();
});
