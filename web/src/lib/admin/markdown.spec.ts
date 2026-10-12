import { describe, expect, it } from 'vitest';
import { renderNotes } from './markdown';

describe('renderNotes', () => {
	it('renders headings, lists, bold and code', () => {
		expect(renderNotes('### Added\n- **Quotas** per user\n- `GET /me`\n\nThanks')).toBe(
			'<h4>Added</h4><ul><li><strong>Quotas</strong> per user</li><li><code>GET /me</code></li></ul><p>Thanks</p>'
		);
	});

	it('joins wrapped list items', () => {
		expect(renderNotes('- first line\n  continued')).toBe('<ul><li>first line continued</li></ul>');
	});

	it('escapes HTML so release notes cannot inject markup', () => {
		const html = renderNotes(
			'<img src=x onerror=alert(1)>\n- <script>alert(1)</script>\n[link](javascript:alert(1))'
		);
		expect(html).not.toMatch(/<img|<script|<a /);
		expect(html).toContain('&lt;img src=x onerror=alert(1)&gt;');
	});
});
