import { execFileSync } from 'node:child_process';
import type { FullConfig } from '@playwright/test';
import { ADMIN, QUOTA_USER, USER } from './fixtures';

// Creates an admin (via the CLI, on the same data dir) and a regular user
// (via the API, since public sign-up is disabled).
export default async function globalSetup(config: FullConfig) {
	const baseURL = config.projects[0].use.baseURL!;
	const dataDir = process.env.ALCOVE_E2E_DATA_DIR!;
	execFileSync('../server/bin/alcove', [
		'superuser',
		'upsert',
		ADMIN.email,
		ADMIN.password,
		`--dir=${dataDir}`
	]);

	const auth = await fetch(`${baseURL}/api/collections/_superusers/auth-with-password`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ identity: ADMIN.email, password: ADMIN.password })
	});
	if (!auth.ok) throw new Error(`admin auth failed: ${auth.status} ${await auth.text()}`);
	const { token } = (await auth.json()) as { token: string };

	// This throwaway instance logs in far more often than a human would: relax
	// the per-IP auth limit (production defaults come from the migration).
	const settings = await fetch(`${baseURL}/api/settings`, { headers: { Authorization: token } });
	const { rateLimits } = (await settings.json()) as {
		rateLimits: { rules: { label: string; maxRequests: number; duration: number }[] };
	};
	for (const rule of rateLimits.rules) if (rule.label === '*:auth') rule.maxRequests = 1000;
	const patched = await fetch(`${baseURL}/api/settings`, {
		method: 'PATCH',
		headers: { 'Content-Type': 'application/json', Authorization: token },
		body: JSON.stringify({ rateLimits })
	});
	if (!patched.ok) throw new Error(`settings update failed: ${patched.status}`);

	const created = await fetch(`${baseURL}/api/collections/users/records`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json', Authorization: token },
		body: JSON.stringify({
			email: USER.email,
			password: USER.password,
			passwordConfirm: USER.password,
			verified: true
		})
	});
	if (!created.ok)
		throw new Error(`user creation failed: ${created.status} ${await created.text()}`);

	const quotaUser = await fetch(`${baseURL}/api/collections/users/records`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json', Authorization: token },
		body: JSON.stringify({
			email: QUOTA_USER.email,
			password: QUOTA_USER.password,
			passwordConfirm: QUOTA_USER.password,
			verified: true,
			quota_bytes: QUOTA_USER.quota
		})
	});
	if (!quotaUser.ok) throw new Error(`quota user creation failed: ${quotaUser.status}`);
}
