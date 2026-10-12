import { ClientResponseError } from 'pocketbase';
import { describe, expect, it } from 'vitest';
import { authErrorKind, mfaIdFrom, totpChallenge } from './errors';
import { safeNext } from './redirect';
import { isEmail } from './validation';

const sdkError = (status: number, response: Record<string, unknown> = {}) =>
	new ClientResponseError({ status, response });

describe('safeNext', () => {
	it.each([
		[null, '/'],
		['', '/'],
		['https://evil.example', '/'],
		['//evil.example', '/'],
		['/\\evil.example', '/'],
		['/files/a?x=1', '/files/a?x=1']
	])('%s -> %s', (input, expected) => {
		expect(safeNext(input)).toBe(expected);
	});
});

describe('authErrorKind', () => {
	it('classifies SDK errors', () => {
		expect(authErrorKind(sdkError(400))).toBe('bad-credentials');
		expect(authErrorKind(sdkError(429))).toBe('too-many');
		expect(authErrorKind(sdkError(0))).toBe('network');
		expect(authErrorKind(sdkError(500))).toBe('unexpected');
		expect(authErrorKind(new Error('x'))).toBe('unexpected');
	});
});

describe('mfaIdFrom', () => {
	it('extracts the MFA id from a 401', () => {
		expect(mfaIdFrom(sdkError(401, { mfaId: 'abc' }))).toBe('abc');
		expect(mfaIdFrom(sdkError(401))).toBeNull();
		expect(mfaIdFrom(sdkError(400, { mfaId: 'abc' }))).toBeNull();
	});
});

describe('isEmail', () => {
	it('accepts plausible addresses only', () => {
		expect(isEmail(' a@b.co ')).toBe(true);
		expect(isEmail('nope')).toBe(false);
		expect(isEmail('a@b')).toBe(false);
	});
});

describe('totpChallenge', () => {
	it('detects the two-factor challenge', () => {
		expect(totpChallenge(sdkError(401, { data: { totpRequired: true } }))).toEqual({
			invalid: false
		});
		expect(totpChallenge(sdkError(401, { data: { totpRequired: true, invalid: true } }))).toEqual({
			invalid: true
		});
		expect(totpChallenge(sdkError(401))).toBeNull();
		expect(totpChallenge(sdkError(400, { data: { totpRequired: true } }))).toBeNull();
	});
});
