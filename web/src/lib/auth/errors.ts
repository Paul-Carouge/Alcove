import { ClientResponseError } from 'pocketbase';

export type AuthErrorKind = 'bad-credentials' | 'too-many' | 'network' | 'unexpected';

/** Maps SDK errors to user-facing categories without leaking server details. */
export function authErrorKind(err: unknown): AuthErrorKind {
	if (err instanceof ClientResponseError) {
		if (err.status === 0) return 'network';
		if (err.status === 429) return 'too-many';
		if (err.status === 400 || err.status === 401 || err.status === 403) return 'bad-credentials';
	}
	return 'unexpected';
}

/** PocketBase answers 401 with an `mfaId` when a second factor is required. */
export function mfaIdFrom(err: unknown): string | null {
	if (err instanceof ClientResponseError && err.status === 401) {
		const id = (err.response as { mfaId?: unknown })?.mfaId;
		return typeof id === 'string' && id !== '' ? id : null;
	}
	return null;
}

/** The server asks for an authenticator code (TOTP enabled on the account). */
export function totpChallenge(err: unknown): { invalid: boolean } | null {
	if (err instanceof ClientResponseError && err.status === 401) {
		const data = (err.response as { data?: { totpRequired?: boolean; invalid?: boolean } })?.data;
		if (data?.totpRequired) return { invalid: data.invalid === true };
	}
	return null;
}
