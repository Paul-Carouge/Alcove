import { execFileSync } from 'node:child_process';
import type { FullConfig } from '@playwright/test';
import { ADMIN, USER } from './fixtures';

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
}
