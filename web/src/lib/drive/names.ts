// Mirrors server/internal/drive.NamePattern; the server stays the authority.
// eslint-disable-next-line no-control-regex -- control characters are exactly what we reject
const NAME = /^(?:[^/\x00-\x1f\x7f]*[^/\x00-\x1f\x7f.][^/\x00-\x1f\x7f]*)$/;

export const isValidName = (name: string) =>
	name.length > 0 && [...name].length <= 255 && NAME.test(name);

/** Folders first, then natural, case-insensitive name order. */
export function compareNodes(
	a: { kind: string; name: string },
	b: { kind: string; name: string },
	locale?: string
) {
	if (a.kind !== b.kind) return a.kind === 'folder' ? -1 : 1;
	return a.name.localeCompare(b.name, locale, { numeric: true, sensitivity: 'base' });
}
