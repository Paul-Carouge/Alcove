import { expect, test, type Browser, type Page } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import { ALBUM_USER, FRIEND_USER, pick } from './fixtures';

const fixture = (name: string) => fileURLToPath(new URL(`./fixtures/${name}`, import.meta.url));

async function signIn(browser: Browser, user: { email: string; password: string }) {
	const page = await (await browser.newContext()).newPage();
	await page.goto('/login');
	await page.getByLabel('Email').fill(user.email);
	await page.getByLabel('Password').fill(user.password);
	await page.getByRole('button', { name: 'Sign in' }).click();
	await expect(page.getByRole('heading', { name: 'My files', level: 1 })).toBeVisible();
	return page;
}

async function upload(page: Page, files: string[]) {
	await page.locator('input[type=file]').setInputFiles(files.map(fixture));
	await expect(page.getByRole('region', { name: 'Uploads' })).toContainText(
		`${files.length} of ${files.length} uploaded`
	);
}

// The second test reuses the album made by the first.
test.describe.configure({ mode: 'serial' });

const nav = (page: Page, name: string) =>
	page.getByRole('navigation').getByRole('link', { name, exact: true }).click();

test('create an album, share it with a contributor, revoke it', async ({ browser }) => {
	test.setTimeout(60_000);
	const owner = await signIn(browser, ALBUM_USER);
	await upload(owner, ['lyon.jpg', 'winter.jpg', 'clip.mp4']);

	// Select two items in the timeline and add them to a new album.
	await nav(owner, 'Photos');
	await expect(owner.getByRole('button', { name: 'Open clip.mp4' })).toBeVisible();
	await owner.getByRole('button', { name: 'Select', exact: true }).click();
	await owner.getByRole('button', { name: 'Select lyon.jpg' }).click();
	await owner.getByRole('button', { name: 'Select clip.mp4' }).click();
	const bar = owner.getByRole('region', { name: 'Selection' });
	await expect(bar).toContainText('2 selected');
	await bar.getByRole('button', { name: 'Add to album' }).click();
	const picker = owner.getByRole('dialog', { name: 'Add 2 items to an album' });
	await picker.getByLabel('Or create an album').fill('Lyon trip');
	await picker.getByRole('button', { name: 'Create and add' }).click();
	await expect(owner.getByRole('status')).toHaveText('2 items added to Lyon trip.');

	// The album card, then the album.
	await nav(owner, 'Albums');
	const card = owner.getByRole('link', { name: /Lyon trip/ });
	await expect(card).toContainText('2 items');
	await card.click();
	await expect(owner.getByRole('heading', { name: 'Lyon trip', level: 1 })).toBeVisible();
	await expect(owner.getByRole('button', { name: /^Open / })).toHaveCount(2);

	// Share with the friend, who can add photos.
	await owner.getByRole('button', { name: 'Share', exact: true }).click();
	const share = owner.getByRole('dialog', { name: 'Share album' });
	await share.getByLabel('Email').fill('nobody@e2e.test');
	await pick(share.getByRole('combobox', { name: 'Role' }), 'Can add photos');
	await share.getByRole('button', { name: 'Add', exact: true }).click();
	await expect(share.getByText('No account with this email on this server.')).toBeVisible();
	await share.getByLabel('Email').fill(FRIEND_USER.email);
	await share.getByRole('button', { name: 'Add', exact: true }).click();
	await expect(share.getByRole('combobox', { name: `Role of ${FRIEND_USER.email}` })).toHaveText(
		'Can add photos'
	);
	await share.getByRole('button', { name: 'Save' }).click();
	await expect(owner.getByText('Shared with 1 person')).toBeVisible();

	// The friend sees the album and plays the shared video (served without access to the owner's drive).
	const friend = await signIn(browser, FRIEND_USER);
	await upload(friend, ['scan.jpg']);
	await nav(friend, 'Albums');
	await expect(friend.getByRole('link', { name: /Lyon trip/ })).toContainText(
		`Shared by ${ALBUM_USER.email}`
	);
	await friend.getByRole('link', { name: /Lyon trip/ }).click();
	await expect(friend.getByText('You can add photos')).toBeVisible();
	await friend.getByRole('button', { name: 'Open clip.mp4' }).click();
	const video = friend.getByRole('dialog', { name: 'clip.mp4' }).locator('video');
	await expect.poll(() => video.evaluate((v: HTMLVideoElement) => v.readyState)).toBeGreaterThan(0);
	await friend.keyboard.press('Escape');

	// …and adds a photo of their own.
	await friend.getByRole('button', { name: 'Add photos' }).click();
	await expect(friend.getByRole('heading', { name: 'Add photos to Lyon trip' })).toBeVisible();
	await friend.getByRole('button', { name: 'Select scan.jpg' }).click();
	await friend.getByRole('button', { name: 'Add to Lyon trip' }).click();
	await expect(friend.getByRole('heading', { name: 'Lyon trip', level: 1 })).toBeVisible();
	await expect(friend.getByRole('button', { name: /^Open / })).toHaveCount(3);

	// The owner sees it arrive live, then stops sharing: the friend's photo leaves with them.
	await expect(owner.getByRole('button', { name: /^Open / })).toHaveCount(3);
	await owner.getByRole('button', { name: 'Share', exact: true }).click();
	await share.getByRole('button', { name: `Remove ${FRIEND_USER.email}` }).click();
	await share.getByRole('button', { name: 'Save' }).click();
	await expect(owner.getByRole('button', { name: /^Open / })).toHaveCount(2);

	await friend.reload();
	await expect(friend.getByRole('heading', { name: 'This album is not available' })).toBeVisible();
});

test('a public link shows the album to visitors without an account', async ({ browser }) => {
	const owner = await signIn(browser, ALBUM_USER);
	await nav(owner, 'Albums');
	await owner.getByRole('link', { name: /Lyon trip/ }).click();
	await owner.getByRole('button', { name: 'Actions for Lyon trip' }).click();
	await owner.getByRole('menuitem', { name: 'Public link' }).click();
	const dialog = owner.getByRole('dialog', { name: /Lyon trip/ });
	await expect(dialog.getByText(/without their location/)).toBeVisible();
	await dialog.getByLabel('Protect with a password').check();
	await dialog.getByLabel('Password', { exact: true }).fill('summer');
	await dialog.getByRole('button', { name: 'Create link' }).click();
	const url = await dialog.getByLabel('Public link', { exact: true }).inputValue();

	const visitor = await (await browser.newContext()).newPage();
	await visitor.goto(url);
	await visitor.getByLabel('Password').fill('summer');
	await visitor.getByRole('button', { name: 'Open' }).click();
	await expect(visitor.getByRole('heading', { name: 'Lyon trip', level: 1 })).toBeVisible();
	await expect(visitor.getByRole('button', { name: /^Open / })).toHaveCount(2);
	await visitor.getByRole('button', { name: 'Open lyon.jpg' }).click();
	const viewer = visitor.getByRole('dialog', { name: 'lyon.jpg' });
	await expect
		.poll(() =>
			viewer
				.getByRole('img', { name: 'lyon.jpg' })
				.evaluate((i: HTMLImageElement) => i.naturalWidth)
		)
		.toBeGreaterThan(0);
	await expect(viewer.getByRole('button', { name: 'Download' })).toHaveCount(0);
	await expect(viewer).not.toContainText('OpenStreetMap');
});
