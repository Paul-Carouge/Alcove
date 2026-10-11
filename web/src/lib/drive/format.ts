const UNITS = ['byte', 'kilobyte', 'megabyte', 'gigabyte', 'terabyte'] as const;

/** Human-readable size using the user's locale ("1,2 Mo" in French). */
export function formatSize(bytes: number, locale: string): string {
	let value = bytes;
	let unit = 0;
	while (value >= 1000 && unit < UNITS.length - 1) {
		value /= 1000;
		unit++;
	}
	return new Intl.NumberFormat(locale, {
		style: 'unit',
		unit: UNITS[unit],
		unitDisplay: 'short',
		maximumFractionDigits: unit === 0 || value >= 100 ? 0 : 1
	}).format(value);
}

/** Time today, otherwise a short date. */
export function formatDate(iso: string, locale: string, now = new Date()): string {
	const date = new Date(iso.replace(' ', 'T'));
	if (Number.isNaN(date.getTime())) return '';
	const sameDay = date.toDateString() === now.toDateString();
	return new Intl.DateTimeFormat(
		locale,
		sameDay
			? { hour: '2-digit', minute: '2-digit' }
			: {
					day: 'numeric',
					month: 'short',
					year: date.getFullYear() === now.getFullYear() ? undefined : 'numeric'
				}
	).format(date);
}

/** Short date with time ("11 Oct, 23:47"), for labels like "Created on …". */
export function formatDateTime(iso: string, locale: string): string {
	const date = new Date(iso.replace(' ', 'T'));
	if (Number.isNaN(date.getTime())) return '';
	return new Intl.DateTimeFormat(locale, {
		day: 'numeric',
		month: 'short',
		hour: '2-digit',
		minute: '2-digit'
	}).format(date);
}
