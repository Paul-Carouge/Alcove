export const escapeHtml = (s: string) =>
	s
		.replace(/&/g, '&amp;')
		.replace(/</g, '&lt;')
		.replace(/>/g, '&gt;')
		.replace(/"/g, '&quot;')
		.replace(/'/g, '&#39;');

/** Inline formatting on already-escaped text: **bold** and `code` only. */
const inline = (s: string) =>
	s.replace(/`([^`]+)`/g, '<code>$1</code>').replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');

/**
 * Renders the small Markdown subset used in release notes (### headings,
 * "- " lists, paragraphs, **bold**, `code`). Everything is HTML-escaped first,
 * so the output is safe to insert; links and raw HTML are shown as text.
 */
export function renderNotes(markdown: string): string {
	const out: string[] = [];
	let list = false;
	const closeList = () => {
		if (list) out.push('</ul>');
		list = false;
	};
	for (const raw of markdown.split(/\r?\n/)) {
		const line = escapeHtml(raw.trimEnd());
		const heading = /^#{1,6}\s+(.*)$/.exec(line);
		const item = /^\s*[-*]\s+(.*)$/.exec(line);
		if (heading) {
			closeList();
			out.push(`<h4>${inline(heading[1]!)}</h4>`);
		} else if (item) {
			if (!list) out.push('<ul>');
			list = true;
			out.push(`<li>${inline(item[1]!)}</li>`);
		} else if (line.trim() === '' || /^-{3,}$/.test(line.trim())) {
			closeList();
		} else if (list && /^\s{2,}/.test(raw)) {
			out[out.length - 1] = out[out.length - 1]!.replace(/<\/li>$/, ` ${inline(line.trim())}</li>`);
		} else {
			closeList();
			out.push(`<p>${inline(line)}</p>`);
		}
	}
	closeList();
	return out.join('');
}
