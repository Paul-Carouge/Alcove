import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';
import { CAL_USER } from './fixtures';

test('an event is created on a day, shown in the month, edited, kept after a reload and deleted', async ({
	page
}) => {
	await page.goto('/login');
	await page.getByLabel('Email').fill(CAL_USER.email);
	await page.getByLabel('Password').fill(CAL_USER.password);
	await page.getByRole('button', { name: 'Sign in' }).click();
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();
	await page.getByRole('navigation').getByRole('link', { name: 'Calendar', exact: true }).click();

	// The first visit creates a calendar.
	await expect(page.getByRole('checkbox', { name: 'Personal' })).toBeChecked();
	const month = page.getByRole('table');
	await month.getByRole('button', { name: /^New event on .*\b20$/ }).click();
	const dialog = page.getByRole('dialog', { name: 'New event' });
	await dialog.getByRole('button', { name: 'Save' }).click();
	await expect(dialog.getByText('Give the event a title.')).toBeVisible();
	await dialog.getByLabel('Title').fill('Team lunch');
	await dialog.getByLabel('Start time').fill('12:00');
	await expect(dialog.getByLabel('End time')).toHaveValue('13:00');
	await dialog.getByLabel('Location').fill('Canteen');

	const { violations } = await new AxeBuilder({ page })
		.withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
		.analyze();
	expect(violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target).join(' ')}`)).toEqual([]);

	await dialog.getByRole('button', { name: 'Save' }).click();
	await expect(dialog).toBeHidden();
	const chip = month.getByRole('button', { name: /Team lunch/ });
	await expect(chip).toContainText('12');

	await chip.click();
	const edit = page.getByRole('dialog', { name: 'Edit event' });
	await expect(edit.getByLabel('Title')).toHaveValue('Team lunch');
	await edit.getByLabel('Title').fill('Team lunch (moved)');
	await edit.getByRole('button', { name: 'Save' }).click();
	await expect(month.getByRole('button', { name: /Team lunch \(moved\)/ })).toBeVisible();

	// Saved on the server.
	await page.reload();
	await expect(month.getByRole('button', { name: /Team lunch \(moved\)/ })).toBeVisible();

	const axe = await new AxeBuilder({ page })
		.withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
		.analyze();
	expect(axe.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target).join(' ')}`)).toEqual(
		[]
	);

	await month.getByRole('button', { name: /Team lunch \(moved\)/ }).click();
	await page
		.getByRole('dialog', { name: 'Edit event' })
		.getByRole('button', { name: 'Delete event' })
		.click();
	await page
		.getByRole('dialog', { name: 'Edit event' })
		.getByRole('button', { name: 'Delete event' })
		.click();
	await expect(page.getByRole('dialog')).toBeHidden();
	await expect(month.getByRole('button', { name: /Team lunch/ })).toHaveCount(0);
	await page.reload();
	await expect(page.getByRole('checkbox', { name: 'Personal' })).toBeChecked();
	await expect(month.getByRole('button', { name: /Team lunch/ })).toHaveCount(0);
});
