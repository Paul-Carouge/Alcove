import { redirect } from '@sveltejs/kit';
import { resolve } from '$app/paths';
import { pb } from '#lib/pb.js';
import type { LayoutLoad } from './$types';

// Every route in (app) requires a signed-in user.
export const load: LayoutLoad = ({ url }) => {
	if (!pb.authStore.isValid) {
		const next = encodeURIComponent(url.pathname + url.search);
		redirect(307, `${resolve('/(public)/login')}?next=${next}`);
	}
};
