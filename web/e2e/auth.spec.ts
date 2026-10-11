import AxeBuilder from '@axe-core/playwright';
import { expect, test, type Page } from '@playwright/test';
import { USER } from './fixtures';

async function expectNoA11yViolations(page: Page) {
	const { violations } = await new AxeBuilder({ page })
		.withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
		.analyze();
	expect(
		violations.flatMap((v) =>
			v.nodes.map((n) => `${v.id}: ${n.target.join(' ')} ${n.failureSummary ?? ''}`)
		)
	).toEqual([]);
}

test('protected pages redirect to sign-in and come back after login', async ({ page }) => {
	await page.goto('/');
	await expect(page).toHaveURL(/\/login\?next=%2F$/);
	await expectNoA11yViolations(page);

	await page.getByLabel('Email').fill(USER.email);
	await page.getByLabel('Password').fill(USER.password);
	await page.getByRole('button', { name: 'Sign in' }).click();

	await expect(page.getByRole('heading', { name: 'My files' })).toBeVisible();
	await expectNoA11yViolations(page);

	// Account menu: identity, theme switch (persisted), then audit it open.
	await page.getByRole('button', { name: 'Account menu' }).click();
	await expect(page.getByText(USER.email)).toBeVisible();
	await page.getByRole('radio', { name: 'Dark' }).click();
	await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
	await expect(page.getByRole('radio', { name: 'Dark' })).toBeVisible(); // menu stays open
	await expectNoA11yViolations(page);
	await page.keyboard.press('Escape');
	await expect(page.getByRole('button', { name: 'Account menu' })).toBeFocused();

	// Session survives a reload, then sign-out returns to the login page.
	await page.reload();
	await expect(page.getByRole('heading', { name: 'My files' })).toBeVisible();
	await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
	await page.getByRole('button', { name: 'Account menu' }).click();
	await page.getByRole('button', { name: 'Sign out' }).click();
	await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
	await page.goto('/');
	await expect(page).toHaveURL(/\/login/);
});

test('mobile navigation drawer opens and closes', async ({ page }) => {
	await page.setViewportSize({ width: 390, height: 780 });
	await page.goto('/login');
	await page.getByLabel('Email').fill(USER.email);
	await page.getByLabel('Password').fill(USER.password);
	await page.getByRole('button', { name: 'Sign in' }).click();
	await page.getByRole('button', { name: 'Open navigation' }).click();
	await expect(page.getByRole('link', { name: 'Files', exact: true })).toBeVisible();
	await expectNoA11yViolations(page);
	await page.getByRole('button', { name: 'Close navigation' }).first().click();
	await expect(page.getByRole('link', { name: 'Files', exact: true })).toBeHidden();
});

test('wrong password shows an error and validation is announced', async ({ page }) => {
	await page.goto('/login');
	await page.getByRole('button', { name: 'Sign in' }).click();
	await expect(page.getByText('This field is required.')).toHaveCount(2);

	await page.getByLabel('Email').fill(USER.email);
	await page.getByLabel('Password').fill('definitely-wrong');
	await page.getByRole('button', { name: 'Sign in' }).click();
	await expect(page.getByRole('alert')).toHaveText('Email or password is incorrect.');
});

test('forgot password never reveals whether the account exists', async ({ page }) => {
	await page.goto('/login');
	await page.getByRole('link', { name: 'Forgot password?' }).click();
	await expect(page.getByRole('heading', { name: 'Reset your password' })).toBeVisible();
	await page.getByLabel('Email').fill('nobody@e2e.test');
	await page.getByRole('button', { name: 'Send link' }).click();
	await expect(page.getByRole('status')).toContainText('If an account exists');
	await expectNoA11yViolations(page);
});

test('an invalid reset link is rejected', async ({ page }) => {
	await page.goto('/reset-password/not-a-real-token');
	await page.getByLabel('New password', { exact: true }).fill('a-new-password-1');
	await page.getByLabel('Confirm new password').fill('a-new-password-1');
	await page.getByRole('button', { name: 'Save password' }).click();
	await expect(page.getByRole('alert')).toContainText('invalid or has expired');
});

test('public sign-up is disabled', async ({ request }) => {
	const res = await request.post('/api/collections/users/records', {
		data: { email: 'intruder@e2e.test', password: 'x'.repeat(12), passwordConfirm: 'x'.repeat(12) }
	});
	expect(res.status()).toBe(403);
});
