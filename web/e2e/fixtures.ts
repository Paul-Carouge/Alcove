import type { Locator } from '@playwright/test';

/** Accounts created by global-setup.ts in the throwaway e2e instance. */
export const ADMIN = { email: 'admin@e2e.test', password: 'e2e-admin-password-123' };
export const USER = { email: 'user@e2e.test', password: 'e2e-user-password-123' };
export const QUOTA_USER = {
	email: 'quota@e2e.test',
	password: 'e2e-quota-password-123',
	quota: 100
};
export const TOTP_USER = { email: 'totp@e2e.test', password: 'e2e-totp-password-123' };
export const ADMIN_USER = { email: 'boss@e2e.test', password: 'e2e-boss-password-123' };
/** Owns the photo timeline tests: other tests upload images to USER. */
export const PHOTO_USER = { email: 'photos@e2e.test', password: 'e2e-photos-password-123' };
/** Album sharing: an owner and a friend with accounts on the same server. */
export const ALBUM_USER = { email: 'albums@e2e.test', password: 'e2e-albums-password-123' };
export const FRIEND_USER = { email: 'friend@e2e.test', password: 'e2e-friend-password-123' };
/** Duplicates and filters. */
export const DUP_USER = { email: 'dups@e2e.test', password: 'e2e-dups-password-123' };
/** Photo map. */
export const MAP_USER = { email: 'map@e2e.test', password: 'e2e-map-password-123' };
export const FAKE_RELEASES_PORT = 8099;

/** Picks an option in a Select (#lib/ui/Select.svelte) the way a pointer user would. */
export async function pick(combobox: Locator, option: string | RegExp) {
	await combobox.click();
	await combobox
		.page()
		.getByRole('option', { name: option, exact: typeof option === 'string' })
		.click();
}
