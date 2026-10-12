import { createApiClient, type components } from '@alcove/api-spec';

export type SetupStatus = components['schemas']['SetupStatus'];
export type SmtpSettings = components['schemas']['SmtpSettings'];

const api = () => createApiClient(window.location.origin);

export class SetupError extends Error {
	constructor(
		readonly status: number,
		message = ''
	) {
		super(message || `setup request failed: ${status}`);
	}
}

export async function setupStatus(token: string): Promise<SetupStatus> {
	const { data, response } = await api().POST('/api/v1/setup/status', { body: { token } });
	if (!data) throw new SetupError(response.status);
	return data;
}

export async function testSmtp(token: string, smtp: SmtpSettings, to: string) {
	const { response, error } = await api().POST('/api/v1/setup/smtp-test', {
		body: { token, smtp, to }
	});
	if (!response.ok) throw new SetupError(response.status, (error as { message?: string })?.message);
}

export async function completeSetup(
	token: string,
	admin: { name: string; email: string; password: string },
	smtp?: SmtpSettings
) {
	const { response } = await api().POST('/api/v1/setup', { body: { token, admin, smtp } });
	if (!response.ok) throw new SetupError(response.status);
}
