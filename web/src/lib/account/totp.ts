import { createApiClient, type components } from '@alcove/api-spec';
import { pb } from '#lib/pb.js';

export type TotpStatus = components['schemas']['TotpStatus'];
export type TotpSetup = components['schemas']['TotpSetup'];

const api = () => createApiClient(window.location.origin);
const auth = () => ({ Authorization: pb.authStore.token });

export class TotpError extends Error {
	constructor(readonly status: number) {
		super(`totp request failed: ${status}`);
	}
}

async function unwrap<T>(p: Promise<{ data?: T; response: Response }>): Promise<T> {
	const { data, response } = await p;
	if (data === undefined) throw new TotpError(response.status);
	return data;
}

export const totpStatus = () => unwrap(api().GET('/api/v1/me/totp', { headers: auth() }));
export const setupTotp = () => unwrap(api().POST('/api/v1/me/totp/setup', { headers: auth() }));
export const enableTotp = (code: string) =>
	unwrap(api().POST('/api/v1/me/totp/enable', { headers: auth(), body: { code } }));
export const regenerateCodes = (password: string, code: string) =>
	unwrap(
		api().POST('/api/v1/me/totp/recovery-codes', { headers: auth(), body: { password, code } })
	);

export async function disableTotp(password: string, code: string) {
	const { response } = await api().POST('/api/v1/me/totp/disable', {
		headers: auth(),
		body: { password, code }
	});
	if (!response.ok) throw new TotpError(response.status);
}
