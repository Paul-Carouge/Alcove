/**
 * Validates a post-login redirect target to prevent open redirects: only
 * same-origin absolute paths are accepted.
 */
export function safeNext(next: string | null | undefined): string {
	if (!next || !next.startsWith('/') || next.startsWith('//') || next.startsWith('/\\')) return '/';
	return next;
}
