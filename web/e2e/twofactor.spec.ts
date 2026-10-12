import { expect, test, type Page } from '@playwright/test';
import { TOTP_USER } from './fixtures';
import { totpCode } from './totp';

async function passwordStep(page: Page) {
	await page.goto('/login');
	await page.getByLabel('Email').fill(TOTP_USER.email);
	await page.getByLabel('Password').fill(TOTP_USER.password);
	await page.getByRole('button', { name: 'Sign in' }).click();
}

async function signOut(page: Page) {
	await page.getByRole('button', { name: 'Account menu' }).click();
	await page.getByRole('button', { name: 'Sign out' }).click();
	await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
}

test('enable TOTP, sign in with a code and a recovery code, then disable', async ({ page }) => {
	// Steps used: enable = now, sign-in = now+1 (the server accepts ±1 step and
	// never the same step twice); later steps use recovery codes.
	await passwordStep(page);
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();

	await page.getByRole('button', { name: 'Account menu' }).click();
	await page.getByRole('link', { name: 'Security' }).click();
	await expect(page.getByRole('heading', { name: 'Security', level: 1 })).toBeVisible();
	await page.getByRole('button', { name: 'Set up two-factor' }).click();

	const setup = page.getByRole('dialog', { name: 'Two-factor authentication' });
	await expect(setup.getByRole('img', { name: 'QR code' })).toBeVisible();
	const secret = (await setup.getByLabel('Secret key').textContent())!.trim();
	await setup.getByLabel('Then enter the 6-digit code it shows').fill(totpCode(secret));
	await setup.getByRole('button', { name: 'Activate' }).click();

	const codesDialog = page.getByRole('dialog', { name: 'Save your recovery codes' });
	await expect(codesDialog.locator('ol code')).toHaveCount(10);
	const codes = await codesDialog.locator('ol code').allTextContents();
	await codesDialog.getByRole('button', { name: 'I have saved them' }).click();
	await expect(page.getByText('On. Signing in requires a code')).toBeVisible();
	await expect(page.getByText('10 recovery codes left')).toBeVisible();

	// Password alone is no longer enough.
	await signOut(page);
	await passwordStep(page);
	await expect(page.getByRole('heading', { name: 'Two-factor authentication' })).toBeVisible();
	await page.getByLabel('Authentication code').fill('000000');
	await page.getByRole('button', { name: 'Verify' }).click();
	await expect(page.getByText('This code is not valid.')).toBeVisible();
	await page.getByLabel('Authentication code').fill(totpCode(secret, 1));
	await page.getByRole('button', { name: 'Verify' }).click();
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();

	// Recovery code path.
	await signOut(page);
	await passwordStep(page);
	await page.getByRole('button', { name: 'Use a recovery code instead' }).click();
	await page.getByLabel('Recovery code').fill(codes[0]!);
	await page.getByRole('button', { name: 'Verify' }).click();
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();

	// Turning it off needs the password and a code.
	await page.getByRole('button', { name: 'Account menu' }).click();
	await page.getByRole('link', { name: 'Security' }).click();
	await expect(page.getByText('9 recovery codes left')).toBeVisible();
	await page.getByRole('button', { name: 'Turn off' }).click();
	const confirm = page.getByRole('dialog', { name: "Confirm it's you" });
	await confirm.getByLabel('Password').fill(TOTP_USER.password);
	await confirm.getByLabel('Code or recovery code').fill(codes[1]!);
	await confirm.getByRole('button', { name: 'Turn off' }).click();
	await expect(page.getByRole('button', { name: 'Set up two-factor' })).toBeVisible();

	await signOut(page);
	await passwordStep(page);
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();
});
