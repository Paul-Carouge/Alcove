// Fake GitHub releases API announcing a newer version (no assets: installing
// it is not possible, which the UI must handle).
import { createServer } from 'node:http';

createServer((req, res) => {
	if (req.url === '/repos/Paul-Carouge/Alcove/releases/latest') {
		res.writeHead(200, { 'Content-Type': 'application/json' });
		res.end(
			JSON.stringify({
				tag_name: 'v99.0.0',
				body: '### Added\n- **Time travel** for files\n- <script>alert(1)</script>',
				html_url: 'https://example.invalid/v99.0.0',
				assets: []
			})
		);
		return;
	}
	res.writeHead(404).end();
}).listen(8099, '127.0.0.1');
