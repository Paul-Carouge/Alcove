<script lang="ts">
	import { Check, Copy, Map as MapIcon, RefreshCw, ScanText, Server } from '@lucide/svelte';
	import { AdminError, applyUpdate, checkUpdates, waitForVersion } from '#lib/admin/api.js';
	import { renderNotes } from '#lib/admin/markdown.js';
	import { system } from '#lib/admin/system.svelte.js';
	import { session } from '#lib/auth/session.svelte.js';
	import { getOCR, installOCR, setOCR, type OCRStatus } from '#lib/documents/api.js';
	import { formatDateTime } from '#lib/drive/format.js';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import { getMapConfig, setMapTiles } from '#lib/photos/api.js';
	import { serverStatus } from '#lib/server-status/store.svelte.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';

	const locale = getLocale();
	const info = $derived(system.current);
	const update = $derived(info?.update);
	const name = $derived(
		serverStatus.current?.kind === 'connected' ? serverStatus.current.health.name : ''
	);

	let checking = $state(false);
	let confirmOpen = $state(false);
	let phase = $state<'idle' | 'installing' | 'restarting' | 'done' | 'failed' | 'timeout'>('idle');
	let error = $state('');
	let copied = $state(false);

	$effect(() => {
		if (session.isAdmin) system.load();
	});

	// Map tiles (ADR 0020).
	let osm = $state<boolean | null>(null);
	let osmSaving = $state(false);
	$effect(() => {
		getMapConfig()
			.then((c) => (osm = !!c.tiles))
			.catch(() => {});
	});
	async function toggleOSM(on: boolean) {
		osmSaving = true;
		try {
			osm = !!(await setMapTiles(on)).tiles;
		} catch {
			error = m.error_unexpected();
		} finally {
			osmSaving = false;
		}
	}

	// Documents and OCR (ADR 0025).
	let ocr = $state<OCRStatus | null>(null);
	let ocrBusy = $state<'saving' | 'installing' | null>(null);
	let ocrError = $state('');
	let hintCopied = $state(false);
	const canOCR = $derived(!!ocr?.tools.tesseract && (ocr?.tools.languages.length ?? 0) > 0);
	const languageNames: Record<string, () => string> = {
		fra: m.language_french,
		eng: m.language_english
	};
	$effect(() => {
		if (session.isAdmin)
			getOCR()
				.then((s) => (ocr = s))
				.catch(() => {});
	});
	async function toggleOCR(on: boolean) {
		ocrBusy = 'saving';
		ocrError = '';
		try {
			ocr = await setOCR(on);
		} catch {
			ocrError = m.error_unexpected();
		} finally {
			ocrBusy = null;
		}
	}
	async function installTools() {
		ocrBusy = 'installing';
		ocrError = '';
		try {
			ocr = await installOCR();
		} catch {
			ocrError = m.ocr_install_failed();
		} finally {
			ocrBusy = null;
		}
	}
	async function copyHint() {
		if (!ocr?.hint) return;
		await navigator.clipboard.writeText(ocr.hint);
		hintCopied = true;
	}

	async function check() {
		checking = true;
		try {
			system.set(await checkUpdates());
		} finally {
			checking = false;
		}
	}

	async function install() {
		confirmOpen = false;
		phase = 'installing';
		try {
			const version = await applyUpdate();
			phase = 'restarting';
			phase = (await waitForVersion(version)) ? 'done' : 'timeout';
		} catch (err) {
			error = err instanceof AdminError && err.message ? err.message : String(err);
			phase = 'failed';
		}
	}

	async function copyCommand() {
		if (!info?.updateCommand) return;
		await navigator.clipboard.writeText(info.updateCommand.split('   ')[0]!);
		copied = true;
	}

	const modeLabel = (mode: string) =>
		mode === 'native'
			? m.install_native()
			: mode === 'docker'
				? m.install_docker()
				: m.install_manual();
</script>

<svelte:head>
	<title>{m.system_title()}</title>
</svelte:head>

<h1>{m.system_title()}</h1>

{#if !session.isAdmin}
	<Alert tone="info">{m.admin_only()}</Alert>
{:else if !info}
	<p class="muted">{m.loading()}</p>
{:else}
	<section class="card" aria-labelledby="about-title">
		<div class="icon" aria-hidden="true"><Server size={22} /></div>
		<div class="body">
			<h2 id="about-title" class="visually-hidden">{m.system_title()}</h2>
			<dl>
				<dt>{m.system_version()}</dt>
				<dd>{name} {info.version}</dd>
				<dt>{m.system_install()}</dt>
				<dd>{modeLabel(info.installMode)}</dd>
				<dt>{m.system_ffmpeg()}</dt>
				<dd class:warn={!info.ffmpeg}>{info.ffmpeg ? m.system_available() : m.system_missing()}</dd>
			</dl>
		</div>
	</section>

	<section class="card" aria-labelledby="map-title">
		<div class="icon" aria-hidden="true"><MapIcon size={22} /></div>
		<div class="body">
			<h2 id="map-title">{m.admin_map_title()}</h2>
			<label class="switch">
				<input
					type="checkbox"
					role="switch"
					checked={osm === true}
					disabled={osm === null || osmSaving}
					onchange={(e) => toggleOSM(e.currentTarget.checked)}
				/>
				{m.admin_map_osm()}
			</label>
			<p class="hint">{m.admin_map_body()}</p>
		</div>
	</section>

	<section class="card" aria-labelledby="ocr-title">
		<div class="icon" class:accent={canOCR && ocr?.enabled} aria-hidden="true">
			<ScanText size={22} />
		</div>
		<div class="body">
			<h2 id="ocr-title">{m.ocr_title()}</h2>
			{#if !ocr}
				<p class="muted small">{m.loading()}</p>
			{:else}
				<p class="hint">{m.ocr_body()}</p>
				<dl>
					<dt>{m.ocr_pdf_text()}</dt>
					<dd class:warn={!ocr.tools.pdfText}>
						{ocr.tools.pdfText ? m.system_available() : m.system_missing()}
					</dd>
					<dt>{m.ocr_engine()}</dt>
					<dd class:warn={!canOCR}>
						{#if canOCR}
							Tesseract {ocr.tools.tesseract} ({ocr.tools.languages
								.map((l) => languageNames[l]?.() ?? l)
								.join(', ')})
						{:else}
							{m.system_missing()}
						{/if}
					</dd>
					<dt>{m.ocr_documents()}</dt>
					<dd>
						{m.ocr_counts({
							ready: ocr.counts.ready,
							pending: ocr.counts.pending,
							failed: ocr.counts.failed
						})}
					</dd>
				</dl>
				{#if canOCR}
					<label class="switch">
						<input
							type="checkbox"
							role="switch"
							checked={ocr.enabled}
							disabled={ocrBusy !== null}
							onchange={(e) => toggleOCR(e.currentTarget.checked)}
						/>
						{m.ocr_enable()}
					</label>
				{:else if ocr.canInstall}
					<div>
						<Button onclick={installTools} loading={ocrBusy === 'installing'}>
							{m.ocr_install()}
						</Button>
					</div>
					<p class="muted small">{m.ocr_install_body()}</p>
				{:else if ocr.hint}
					<p class="muted small">{m.ocr_hint()}</p>
					<div class="command">
						<code>{ocr.hint}</code>
						<Button variant="secondary" onclick={copyHint}>
							{#if hintCopied}<Check size={16} aria-hidden="true" />{:else}<Copy
									size={16}
									aria-hidden="true"
								/>{/if}
							{m.system_copy()}
						</Button>
					</div>
				{/if}
				{#if ocrError}<Alert>{ocrError}</Alert>{/if}
			{/if}
		</div>
	</section>

	<section class="card" aria-labelledby="updates-title">
		<div class="icon" class:accent={update?.available} aria-hidden="true">
			<RefreshCw size={22} />
		</div>
		<div class="body">
			<h2 id="updates-title">{m.system_updates()}</h2>

			{#if phase === 'installing'}
				<p role="status">{m.update_installing({ version: update?.latest ?? '' })}</p>
			{:else if phase === 'restarting'}
				<p role="status">{m.update_restarting()}</p>
			{:else if phase === 'done'}
				<Alert tone="success">{m.update_done({ name, version: update?.latest ?? '' })}</Alert>
				<div><Button onclick={() => location.reload()}>{m.update_reload()}</Button></div>
			{:else if phase === 'failed'}
				<Alert>{m.update_failed({ error })}</Alert>
			{:else if phase === 'timeout'}
				<Alert>{m.update_timeout()}</Alert>
			{/if}

			{#if phase === 'idle' || phase === 'failed'}
				{#if update?.available}
					<p class="lead">{m.system_update_available({ version: update.latest ?? '' })}</p>
					{#if update.notes}
						<!-- renderNotes escapes all HTML before formatting. -->
						<!-- eslint-disable-next-line svelte/no-at-html-tags -->
						<div class="notes">{@html renderNotes(update.notes)}</div>
					{/if}
					{#if info.canSelfUpdate}
						<div>
							<Button onclick={() => (confirmOpen = true)}
								>{m.system_update_now({ version: update.latest ?? '' })}</Button
							>
						</div>
					{:else if info.updateCommand}
						<p class="muted small">{m.system_update_command()}</p>
						<div class="command">
							<code>{info.updateCommand}</code>
							<Button variant="secondary" onclick={copyCommand}>
								{#if copied}<Check size={16} aria-hidden="true" />{:else}<Copy
										size={16}
										aria-hidden="true"
									/>{/if}
								{m.system_copy()}
							</Button>
						</div>
					{/if}
				{:else}
					<p>{m.system_up_to_date()}</p>
				{/if}

				{#if !update?.enabled}
					<p class="muted small">{m.system_check_disabled()}</p>
				{:else if update.error}
					<p class="muted small">{m.system_check_error({ error: update.error })}</p>
				{/if}
				<div class="row">
					<span class="muted small">
						{update?.checkedAt && !update.checkedAt.startsWith('0001')
							? m.system_checked({ date: formatDateTime(update.checkedAt, locale) })
							: m.system_never_checked()}
					</span>
					<Button variant="ghost" onclick={check} loading={checking}>{m.system_check_now()}</Button>
				</div>
			{/if}
		</div>
	</section>
{/if}

<Dialog bind:open={confirmOpen} title={m.update_confirm_title({ version: update?.latest ?? '' })}>
	<p class="muted">{m.update_confirm_body()}</p>
	<div class="actions">
		<Button variant="ghost" onclick={() => (confirmOpen = false)}>{m.cancel_button()}</Button>
		<Button onclick={install}>{m.system_update_now({ version: update?.latest ?? '' })}</Button>
	</div>
</Dialog>

<style>
	h1 {
		margin: 0 0 var(--space-6);
		padding-top: var(--space-3);
	}
	.switch {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		gap: var(--space-3);
		min-height: 2.75rem;
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		cursor: pointer;
	}
	.hint {
		margin: var(--space-1) 0 0;
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.card {
		display: flex;
		gap: var(--space-5);
		max-width: 48rem;
		margin-bottom: var(--space-5);
		padding: var(--space-6);
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-xl);
		box-shadow: var(--shadow-sm);
	}
	.icon {
		display: grid;
		place-items: center;
		flex: none;
		width: 3rem;
		height: 3.5rem;
		padding-top: var(--space-1);
		border-radius: var(--radius-full) var(--radius-full) var(--radius-md) var(--radius-md);
		background: var(--color-surface-sunken);
		color: var(--color-text-muted);
	}
	.icon.accent {
		background: var(--color-accent-subtle);
		color: var(--color-accent);
	}
	.body {
		flex: 1;
		min-width: 0;
		display: grid;
		gap: var(--space-3);
	}
	h2 {
		font-size: var(--text-xl);
	}
	@media (max-width: 600px) {
		.card {
			flex-direction: column;
			gap: var(--space-4);
			padding: var(--space-5) var(--space-4);
		}
		dl {
			grid-template-columns: 1fr;
			gap: 0;
		}
		dd + dt {
			margin-top: var(--space-3);
		}
	}
	p {
		margin: 0;
	}
	.lead {
		font-weight: var(--weight-medium);
	}
	.muted {
		color: var(--color-text-muted);
	}
	.small {
		font-size: var(--text-sm);
	}
	dl {
		display: grid;
		grid-template-columns: auto 1fr;
		gap: var(--space-2) var(--space-5);
		margin: 0;
	}
	dl {
		font-size: var(--text-sm);
	}
	dt {
		color: var(--color-text-muted);
	}
	dd {
		font-variant-numeric: tabular-nums;
	}
	dd {
		margin: 0;
	}
	dd.warn {
		color: var(--color-warning);
	}
	.notes {
		max-height: 18rem;
		overflow: auto;
		padding: var(--space-4) var(--space-5);
		border-radius: var(--radius-lg);
		background: var(--color-surface-sunken);
		font-size: var(--text-sm);
	}
	.notes :global(h4) {
		margin: var(--space-3) 0 var(--space-1);
		font-size: var(--text-sm);
	}
	.notes :global(h4:first-child) {
		margin-top: 0;
	}
	.notes :global(ul) {
		margin: 0;
		padding-left: var(--space-5);
	}
	.notes :global(code) {
		font-family: var(--font-mono);
	}
	.command {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}
	.command code {
		flex: 1;
		min-width: 0;
		padding: var(--space-2) var(--space-3);
		border-radius: var(--radius-md);
		border: 1px solid var(--color-border);
		background: var(--color-surface-sunken);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		overflow-wrap: anywhere;
	}
	.row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
	}
	.actions {
		display: flex;
		justify-content: flex-end;
		gap: var(--space-2);
	}
</style>
