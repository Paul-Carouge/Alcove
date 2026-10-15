import { escapeHtml } from '#lib/admin/markdown.js';

/** Inline formatting on already-escaped text: `code`, **bold**, *italic*, [links](https://…). */
function inline(s: string): string {
	// Code spans and link targets are set aside first, so the emphasis rules cannot touch them.
	const kept: string[] = [];
	const keep = (html: string) => `\uE000${kept.push(html) - 1}\uE000`;
	s = s
		.replace(/`([^`]+)`/g, (_, c: string) => keep(`<code>${c}</code>`))
		// Only http(s) links; the URL is already escaped, so it cannot close the attribute.
		.replace(
			/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g,
			(_, text: string, url: string) =>
				keep(`<a href="${url}" target="_blank" rel="noopener noreferrer">`) + text + keep('</a>')
		)
		.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
		.replace(/(^|[^*\w])\*([^*\s][^*]*)\*/g, '$1<em>$2</em>')
		.replace(/(^|[^\w])_([^_\s][^_]*)_(?!\w)/g, '$1<em>$2</em>');
	return s.replace(/\uE000(\d+)\uE000/g, (_, i: string) => kept[Number(i)]!);
}

/**
 * Renders the Markdown of a note: headings, paragraphs, bullet, numbered and task lists, quotes,
 * code blocks, rules, and inline code, bold, italic and http(s) links. Everything is HTML-escaped
 * first, so the output is safe to insert; raw HTML is shown as text.
 */
export function renderMarkdown(markdown: string): string {
	// U+E000 delimits kept fragments in inline(); typed ones must not expand.
	markdown = markdown.replaceAll('\uE000', '');
	const out: string[] = [];
	let block: 'ul' | 'ol' | 'quote' | 'p' | null = null;
	let code: string[] | null = null;
	const close = () => {
		if (block === 'ul') out.push('</ul>');
		else if (block === 'ol') out.push('</ol>');
		else if (block === 'quote') out.push('</blockquote>');
		else if (block === 'p') out.push('</p>');
		block = null;
	};
	const open = (kind: NonNullable<typeof block>, tag: string) => {
		if (block === kind) return false;
		close();
		out.push(tag);
		block = kind;
		return true;
	};

	for (const raw of markdown.split(/\r?\n/)) {
		if (code) {
			if (/^\s*```/.test(raw)) {
				out.push(`<pre><code>${code.join('\n')}</code></pre>`);
				code = null;
			} else code.push(escapeHtml(raw));
			continue;
		}
		if (/^\s*```/.test(raw)) {
			close();
			code = [];
			continue;
		}
		const line = escapeHtml(raw.trimEnd());
		let match: RegExpExecArray | null;
		if ((match = /^(#{1,6})\s+(.*)$/.exec(line))) {
			close();
			const level = Math.min(match[1]!.length + 1, 4);
			out.push(`<h${level}>${inline(match[2]!)}</h${level}>`);
		} else if (/^\s*([-*_])(\s*\1){2,}\s*$/.test(line)) {
			close();
			out.push('<hr>');
		} else if ((match = /^\s*[-*+]\s+\[( |x|X)\]\s+(.*)$/.exec(line))) {
			open('ul', '<ul>');
			const done = match[1] !== ' ';
			out.push(
				`<li class="task${done ? ' done' : ''}"><input type="checkbox" disabled${done ? ' checked' : ''}> ${inline(match[2]!)}</li>`
			);
		} else if ((match = /^\s*[-*+]\s+(.*)$/.exec(line))) {
			open('ul', '<ul>');
			out.push(`<li>${inline(match[1]!)}</li>`);
		} else if ((match = /^\s*\d+[.)]\s+(.*)$/.exec(line))) {
			open('ol', '<ol>');
			out.push(`<li>${inline(match[1]!)}</li>`);
		} else if ((match = /^&gt;\s?(.*)$/.exec(line))) {
			if (!open('quote', '<blockquote>')) out.push('<br>');
			out.push(inline(match[1]!));
		} else if (line.trim() === '') {
			close();
		} else {
			if (!open('p', '<p>')) out.push('<br>');
			out.push(inline(line));
		}
	}
	if (code) out.push(`<pre><code>${code.join('\n')}</code></pre>`);
	close();
	return out.join('');
}
