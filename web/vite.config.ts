import { paraglideVitePlugin } from '@inlang/paraglide-js';
import { defineConfig } from 'vitest/config';
import adapter from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';

// Dev server proxies API calls to the Go server (make dev runs both).
const backend = process.env.ALCOVE_DEV_BACKEND ?? 'http://127.0.0.1:8090';

export default defineConfig({
	plugins: [
		sveltekit({
			compilerOptions: {
				// Force runes mode for the project, except for libraries. Can be removed in svelte 6.
				runes: ({ filename }) =>
					filename.split(/[/\\]/).includes('node_modules') ? undefined : true
			},
			// Static SPA embedded in the Go binary; unknown paths fall back to index.html.
			adapter: adapter({ fallback: 'index.html', strict: true }),
			// script-src via hashes in a <meta> tag; the server sends the rest of the CSP.
			csp: { mode: 'hash', directives: { 'script-src': ['self'] } }
		}),

		paraglideVitePlugin({
			project: './project.inlang',
			outdir: './src/lib/paraglide',
			emitTsDeclarations: true,
			// No locale in URLs: remembered choice, then browser language, then English.
			strategy: ['localStorage', 'preferredLanguage', 'baseLocale']
		})
	],
	server: {
		proxy: {
			'/health': backend,
			'/api': { target: backend, ws: false },
			'/_': backend
		}
	},
	test: {
		expect: { requireAssertions: true },
		include: ['src/**/*.{test,spec}.{js,ts}'],
		environment: 'node'
	}
});
