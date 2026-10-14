import { createApiClient } from '@alcove/api-spec';
import { pb } from '#lib/pb.js';

/**
 * Downloads files and folders (with their content) or an album as one ZIP: the server prepares a
 * short-lived link, which the browser then downloads like any file.
 */
export async function downloadZip(what: { nodes: string[] } | { album: string }, name?: string) {
	const { data, response } = await createApiClient(window.location.origin).POST('/api/v1/zip', {
		headers: { Authorization: pb.authStore.token },
		body: { ...what, ...(name ? { name } : {}) }
	});
	if (!data) throw new Error(`zip failed: ${response.status}`);
	const a = document.createElement('a');
	a.href = data.url;
	a.rel = 'noopener';
	a.click();
	return data.files;
}
