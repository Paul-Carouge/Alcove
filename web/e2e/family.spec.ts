import { expect, test, type Browser, type Page } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import { ADMIN_USER } from './fixtures';

const fixture = (name: string) => fileURLToPath(new URL(`./fixtures/${name}`, import.meta.url));

async function signIn(browser: Browser, email: string, password: string): Promise<Page> {
	const page = await (await browser.newContext()).newPage();
	await page.goto('/login');
	await page.getByLabel('Email').fill(email);
	await page.getByLabel('Password').fill(password);
	await page.getByRole('button', { name: 'Sign in' }).click();
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();
	return page;
}

test('an administrator creates a family account, which then manages itself', async ({
	browser
}) => {
	test.setTimeout(60_000);
	const admin = await signIn(browser, ADMIN_USER.email, ADMIN_USER.password);
	await admin.getByRole('button', { name: 'Account menu' }).click();
	await admin.getByRole('link', { name: 'Users' }).click();
	await expect(admin.getByRole('heading', { name: 'Users', level: 1 })).toBeVisible();

	// Create the account; the generated password is shown once.
	await admin.getByRole('button', { name: 'New account' }).click();
	const dialog = admin.getByRole('dialog', { name: 'New account' });
	await dialog.getByLabel('Email').fill('lea@e2e.test');
	await dialog.getByLabel('Name').fill('Léa');
	await dialog.getByLabel('Storage quota (GB)').fill('1');
	await dialog.getByRole('button', { name: 'Create' }).click();
	const handover = admin.getByRole('dialog', { name: 'New password' });
	const password = (await handover.locator('code').textContent())!.trim();
	expect(password).toMatch(/^[a-zA-Z2-9]{4}(-[a-zA-Z2-9]{4}){3}$/);
	await handover.getByRole('button', { name: 'Done' }).click();
	await expect(admin.getByRole('status').filter({ hasText: 'Account created' })).toHaveText(
		'Account created for lea@e2e.test.'
	);
	await expect(admin.getByRole('listitem').filter({ hasText: 'Léa' })).toContainText('of 1 GB');

	// Léa signs in and chooses her own password.
	const lea = await signIn(browser, 'lea@e2e.test', password);
	await lea.getByRole('button', { name: 'Account menu' }).click();
	await lea.getByRole('link', { name: 'Account', exact: true }).click();
	await lea.getByLabel('Current password').fill('not-it-at-all');
	await lea.getByLabel('New password', { exact: true }).fill('lea-own-password-1');
	await lea.getByLabel('Confirm new password').fill('lea-own-password-1');
	await lea.getByRole('button', { name: 'Change password' }).click();
	await expect(lea.getByText('The current password is not right.')).toBeVisible();
	await lea.getByLabel('Current password').fill(password);
	await lea.getByRole('button', { name: 'Change password' }).click();
	await expect(lea.getByText('Your password was changed. Sign in with the new one.')).toBeVisible();
	await lea.getByLabel('Email').fill('lea@e2e.test');
	await lea.getByLabel('Password').fill('lea-own-password-1');
	await lea.getByRole('button', { name: 'Sign in' }).click();
	await expect(lea.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();

	// Photos: move one to the trash from the selection; find the other by name.
	await lea.locator('input[type=file]').setInputFiles([fixture('lyon.jpg'), fixture('winter.jpg')]);
	await expect(lea.getByRole('region', { name: 'Uploads' })).toContainText('2 of 2 uploaded');
	await lea.getByRole('navigation').getByRole('link', { name: 'Photos', exact: true }).click();
	await expect(lea.getByRole('button', { name: /^Open / })).toHaveCount(2);
	await lea.getByRole('button', { name: 'Select', exact: true }).click();
	await lea.getByRole('button', { name: 'Select winter.jpg' }).click();
	await lea
		.getByRole('region', { name: 'Selection' })
		.getByRole('button', { name: 'Move to trash' })
		.click();
	await expect(lea.getByRole('status').first()).toHaveText('1 item moved to the trash.');
	await expect(lea.getByRole('button', { name: /^Open / })).toHaveCount(1);

	await lea.getByRole('navigation').getByRole('link', { name: 'Files', exact: true }).click();
	await lea.getByRole('searchbox', { name: 'Search files' }).fill('LYON');
	await lea.keyboard.press('Enter');
	await expect(lea.getByRole('heading', { name: 'Search', level: 1 })).toBeVisible();
	await expect(lea.getByText('1 result')).toBeVisible();
	await expect(lea.getByRole('link', { name: 'lyon.jpg' })).toBeVisible();

	// The administrator sees her usage, resets her password, then deletes the account.
	await admin.reload();
	const row = admin.getByRole('listitem').filter({ hasText: 'Léa' });
	await expect(row).not.toContainText('0 B of');
	await row.getByRole('button', { name: 'Actions for Léa' }).click();
	await admin.getByRole('menuitem', { name: 'Reset password' }).click();
	await expect(admin.getByRole('dialog', { name: 'New password' }).locator('code')).toHaveText(
		/^[a-zA-Z2-9-]{19}$/
	);
	await admin.getByRole('button', { name: 'Done' }).click();
	await row.getByRole('button', { name: 'Actions for Léa' }).click();
	await admin.getByRole('menuitem', { name: 'Delete account' }).click();
	const confirm = admin.getByRole('dialog', { name: 'Delete lea@e2e.test?' });
	const del = confirm.getByRole('button', { name: 'Delete account' });
	await expect(del).toBeDisabled();
	await confirm.getByLabel('Type the email address to confirm').fill('lea@e2e.test');
	await del.click();
	await expect(admin.getByRole('status').filter({ hasText: 'deleted' })).toHaveText(
		'Account lea@e2e.test deleted.'
	);
	await expect(admin.getByRole('listitem').filter({ hasText: 'Léa' })).toHaveCount(0);
});
