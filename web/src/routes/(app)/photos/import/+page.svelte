<script lang="ts">
	import { resolve } from '$app/paths';
	import {
		ArrowLeft,
		Check,
		ExternalLink,
		FolderArchive,
		HardDrive,
		RefreshCw,
		RotateCcw,
		Trash2,
		Upload,
		X
	} from '@lucide/svelte';
	import { onDestroy } from 'svelte';
	import { listUsers, type AdminUser } from '#lib/admin/api.js';
	import { session } from '#lib/auth/session.svelte.js';
	import { formatSize } from '#lib/drive/format.js';
	import { m } from '#lib/paraglide/messages.js';
	import { getLocale } from '#lib/paraglide/runtime.js';
	import {
		ImportError,
		TAKEOUT_URL,
		cancelImport,
		failuresCsv,
		isActive,
		latestImport,
		listImportUploads,
		listServerFiles,
		percent,
		startImport,
		stepOf,
		newer,
		watchImport,
		type ImportFailure,
		type ImportJob,
		type ImportStep,
		type ServerFile
	} from '#lib/photos/takeout.js';
	import { ArchiveUploads } from '#lib/photos/takeoutUploads.svelte.js';
	import Alert from '#lib/ui/Alert.svelte';
	import Button from '#lib/ui/Button.svelte';
	import Dialog from '#lib/ui/Dialog.svelte';
	import Select from '#lib/ui/Select.svelte';

	const locale = getLocale();
	const DISMISS_KEY = 'alcove.import.dismissed';
	const SHOWN_FAILURES = 50;

	let job = $state<ImportJob | null>(null);
	let loaded = $state(false);
	let dismissed = $state<string | null>(readDismissed());
	let chosen = $state(false);
	let source = $state<'upload' | 'server'>('upload');
	let starting = $state(false);
	let startError = $state('');
	let confirmCancel = $state(false);
	let cancelling = $state(false);

	const archives = new ArchiveUploads();
	let picker = $state<HTMLInputElement>();

	// Server folder (administrators).
	let serverDir = $state('');
	let serverFiles = $state<ServerFile[] | null>(null);
	let serverError = $state(false);
	let picked = $state<string[]>([]);
	let users = $state<AdminUser[]>([]);
	let target = $state<string>(session.user?.id ?? '');

	const step = $derived<ImportStep>(stepOf(job, dismissed) ?? (chosen ? 'source' : 'intro'));
	const steps: { id: ImportStep; label: () => string }[] = [
		{ id: 'intro', label: m.import_step_takeout },
		{ id: 'source', label: m.import_step_source },
		{ id: 'progress', label: m.import_step_progress },
		{ id: 'report', label: m.import_step_report }
	];
	const stepIndex = $derived(steps.findIndex((s) => s.id === step));

	function readDismissed(): string | null {
		try {
			return localStorage.getItem(DISMISS_KEY);
		} catch {
			return null;
		}
	}

	$effect(() => {
		latestImport()
			.then((j) => (job = j))
			.catch(() => {})
			.finally(() => (loaded = true));
	});

	// Follow the job live while it runs.
	const watched = $derived(isActive(job) ? job!.id : '');
	$effect(() => {
		const id = watched;
		if (!id) return;
		let stop: (() => void) | undefined;
		let gone = false;
		watchImport(id, (j) => (job = newer(job, j))).then((s) => (gone ? s() : (stop = s)));
		return () => {
			gone = true;
			stop?.();
		};
	});

	onDestroy(() => archives.pause());

	// Archives uploaded during an earlier visit and not used yet.
	$effect(() => {
		if (step !== 'source') return;
		listImportUploads()
			.then((list) => archives.load(list))
			.catch(() => {});
	});

	async function loadServer() {
		serverError = false;
		try {
			const res = await listServerFiles();
			serverDir = res.dir;
			serverFiles = res.items;
			picked = picked.filter((p) => res.items.some((f) => f.name === p));
			if (!users.length) users = await listUsers();
		} catch {
			serverError = true;
		}
	}

	function chooseSource(s: 'upload' | 'server') {
		source = s;
		startError = '';
		if (s === 'server' && serverFiles === null) loadServer();
	}

	function togglePicked(name: string) {
		picked = picked.includes(name) ? picked.filter((p) => p !== name) : [...picked, name];
	}

	const canStart = $derived(
		source === 'upload' ? archives.ready : picked.length > 0 && target !== ''
	);

	async function start() {
		starting = true;
		startError = '';
		try {
			job =
				source === 'upload'
					? await startImport({ uploads: archives.ids })
					: await startImport({
							serverFiles: picked,
							user: target === session.user?.id ? undefined : target
						});
			archives.items = [];
		} catch (err) {
			startError =
				err instanceof ImportError && err.status === 409
					? m.import_start_conflict()
					: m.import_start_error();
		} finally {
			starting = false;
		}
	}

	async function cancel() {
		if (!job) return;
		cancelling = true;
		try {
			await cancelImport(job.id);
			confirmCancel = false;
		} finally {
			cancelling = false;
		}
	}

	function again() {
		if (job) {
			dismissed = job.id;
			try {
				localStorage.setItem(DISMISS_KEY, job.id);
			} catch {
				// Private mode: the report shows again next visit.
			}
		}
		chosen = false;
	}

	const reasonLabel = (r: ImportFailure['reason']) =>
		({
			unreadable: m.import_reason_unreadable,
			too_large: m.import_reason_too_large,
			suspicious_compression: m.import_reason_suspicious_compression,
			unsupported: m.import_reason_unsupported,
			save_failed: m.import_reason_save_failed
		})[r]();

	const errorLabel = (code: string) =>
		(
			({
				quota_exceeded: m.import_error_quota_exceeded,
				disk_full: m.import_error_disk_full,
				no_photos: m.import_error_no_photos,
				unreadable: m.import_error_unreadable,
				too_many_entries: m.import_error_too_many_entries,
				unsafe_archive: m.import_error_unsafe_archive,
				interrupted: m.import_error_interrupted
			}) as Record<string, () => string>
		)[code]?.() ?? m.import_error_internal();

	function downloadCsv() {
		if (!job?.failures) return;
		const csv = failuresCsv(
			job.failures,
			[m.import_failures_file(), m.import_failures_reason()],
			reasonLabel
		);
		const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
		const a = document.createElement('a');
		a.href = url;
		a.download = 'google-photos-import-failures.csv';
		a.click();
		setTimeout(() => URL.revokeObjectURL(url), 1000);
	}

	const counts = $derived(
		job
			? [
					{ label: m.import_count_imported(), value: job.imported },
					{ label: m.import_count_duplicates(), value: job.duplicates },
					{ label: m.import_count_skipped(), value: job.skipped },
					{ label: m.import_count_undated(), value: job.undated },
					{ label: m.import_count_failed(), value: job.failed },
					{ label: m.import_count_albums(), value: job.albums }
				]
			: []
	);
	const num = (n: number) => new Intl.NumberFormat(locale).format(n);
	const pct = (n: number) => new Intl.NumberFormat(locale, { style: 'percent' }).format(n / 100);
</script>

<svelte:head>
	<title>{m.import_title()}</title>
</svelte:head>

<a class="back" href={resolve('/(app)/photos')}>
	<ArrowLeft size={16} aria-hidden="true" />{m.import_back()}
</a>
<h1>{m.import_title()}</h1>
<p class="intro">{m.import_intro()}</p>

<ol class="steps" aria-label={m.import_steps_label()}>
	{#each steps as s, i (s.id)}
		<li
			class:current={i === stepIndex}
			class:past={i < stepIndex}
			aria-current={i === stepIndex ? 'step' : undefined}
		>
			<span class="dot" aria-hidden="true">
				{#if i < stepIndex}<Check size={14} />{:else}{i + 1}{/if}
			</span>
			<span class="step-label">{s.label()}</span>
		</li>
	{/each}
</ol>

{#if !loaded}
	<div class="card skeleton" aria-hidden="true"></div>
{:else if step === 'intro'}
	<section class="card" aria-labelledby="takeout-heading">
		<h2 id="takeout-heading">{m.import_takeout_heading()}</h2>
		<p>{m.import_takeout_body()}</p>
		<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- external link to Google Takeout -->
		<a class="takeout-link" href={TAKEOUT_URL} target="_blank" rel="noopener noreferrer">
			{m.import_takeout_open()}<ExternalLink size={16} aria-hidden="true" />
			<span class="visually-hidden">{m.import_takeout_new_tab()}</span>
		</a>
		<h3>{m.import_takeout_options()}</h3>
		<ul class="checks">
			<li><Check size={16} aria-hidden="true" />{m.import_takeout_opt_only()}</li>
			<li><Check size={16} aria-hidden="true" />{m.import_takeout_opt_zip()}</li>
			<li><Check size={16} aria-hidden="true" />{m.import_takeout_opt_size()}</li>
			<li><Check size={16} aria-hidden="true" />{m.import_takeout_opt_all()}</li>
		</ul>
		<p class="muted">{m.import_takeout_notes()}</p>
		<div class="actions">
			<Button onclick={() => (chosen = true)}>{m.import_next()}</Button>
		</div>
	</section>
{:else if step === 'source'}
	<section class="card" aria-labelledby="source-heading">
		<h2 id="source-heading">{m.import_source_heading()}</h2>
		{#if session.isAdmin}
			<div class="segmented" role="radiogroup" aria-label={m.import_source_label()}>
				<button
					role="radio"
					aria-checked={source === 'upload'}
					onclick={() => chooseSource('upload')}
				>
					<Upload size={16} aria-hidden="true" />{m.import_source_upload()}
				</button>
				<button
					role="radio"
					aria-checked={source === 'server'}
					onclick={() => chooseSource('server')}
				>
					<HardDrive size={16} aria-hidden="true" />{m.import_source_server()}
				</button>
			</div>
		{/if}

		{#if source === 'upload'}
			<p>{m.import_upload_body()}</p>
			<input
				bind:this={picker}
				class="visually-hidden"
				type="file"
				accept=".zip,application/zip"
				multiple
				tabindex="-1"
				aria-hidden="true"
				onchange={(e) => {
					archives.add(e.currentTarget.files ?? []);
					e.currentTarget.value = '';
				}}
			/>
			<Button variant="secondary" onclick={() => picker?.click()}>
				<FolderArchive size={16} aria-hidden="true" />{m.import_upload_pick()}
			</Button>
			{#if archives.items.length}
				<ul class="files">
					{#each archives.items as a (a.key)}
						{@const failed = a.status === 'error' || a.status === 'disk' || a.status === 'limit'}
						<li>
							<div class="file-head">
								{#if a.status === 'done'}
									<input
										type="checkbox"
										bind:checked={a.selected}
										aria-label={m.import_upload_use({ name: a.name })}
									/>
								{/if}
								<bdi class="name">{a.name}</bdi>
								<span class="file-status" class:error={failed}>
									{#if a.status === 'done'}<Check size={14} aria-hidden="true" />{a.stored
											? m.import_upload_earlier()
											: m.import_upload_done()}
									{:else if a.status === 'uploading'}{m.import_upload_progress({
											sent: formatSize(a.sent, locale),
											size: formatSize(a.size, locale)
										})}
									{:else if a.status === 'queued'}{m.import_upload_waiting()}
									{:else if a.status === 'disk'}{m.import_upload_disk()}
									{:else if a.status === 'limit'}{m.import_upload_limit()}
									{:else}{m.import_upload_error()}{/if}
								</span>
								{#if failed}
									<button
										class="icon-btn"
										aria-label={m.import_upload_retry()}
										title={m.import_upload_retry()}
										onclick={() => archives.retry(a.key)}
									>
										<RotateCcw size={16} aria-hidden="true" />
									</button>
								{/if}
								<button
									class="icon-btn"
									aria-label={a.id
										? m.import_upload_delete({ name: a.name })
										: m.import_upload_remove({ name: a.name })}
									title={a.id
										? m.import_upload_delete({ name: a.name })
										: m.import_upload_remove({ name: a.name })}
									onclick={() => archives.remove(a.key)}
								>
									{#if a.id}<Trash2 size={16} aria-hidden="true" />{:else}<X
											size={16}
											aria-hidden="true"
										/>{/if}
								</button>
							</div>
							{#if a.status !== 'done'}
								<progress max={a.size || 1} value={a.sent} aria-label={a.name}></progress>
							{/if}
						</li>
					{/each}
				</ul>
			{/if}
		{:else}
			<p>{m.import_server_body()}</p>
			{#if serverDir}<code class="path">{serverDir}</code>{/if}
			{#if serverError}
				<Alert>{m.import_server_error()}</Alert>
			{:else if serverFiles && serverFiles.length === 0}
				<p class="muted">{m.import_server_empty()}</p>
			{:else if serverFiles}
				<ul class="files picks">
					{#each serverFiles as f (f.name)}
						<li>
							<label>
								<input
									type="checkbox"
									checked={picked.includes(f.name)}
									onchange={() => togglePicked(f.name)}
								/>
								<span class="name">{f.name}</span>
								<span class="muted">
									{f.kind === 'folder' ? m.import_server_folder() : formatSize(f.size, locale)}
								</span>
							</label>
						</li>
					{/each}
				</ul>
			{/if}
			<Button variant="ghost" onclick={loadServer}>
				<RefreshCw size={16} aria-hidden="true" />{m.import_server_refresh()}
			</Button>
			{#if users.length}
				<div class="field">
					<span id="import-user-label">{m.import_server_user()}</span>
					<Select
						labelledby="import-user-label"
						bind:value={target}
						options={users.map((u) => ({
							value: u.id,
							label: u.name ? `${u.name} (${u.email})` : u.email
						}))}
					/>
				</div>
			{/if}
		{/if}

		{#if startError}<Alert>{startError}</Alert>{/if}
		<div class="actions">
			<Button onclick={start} disabled={!canStart} loading={starting}>{m.import_start()}</Button>
		</div>
	</section>
{:else if step === 'progress' && job}
	<section class="card" aria-labelledby="progress-heading">
		<h2 id="progress-heading">{m.import_progress_heading()}</h2>
		<p class="status-line" role="status">
			{#if job.status === 'queued'}{m.import_status_queued()}
			{:else if job.status === 'scanning'}{m.import_status_scanning()}
			{:else}{m.import_status_running({
					processed: num(job.processed),
					total: num(job.total)
				})}{/if}
		</p>
		<div class="bar">
			<progress
				class="big"
				max="100"
				value={job.status === 'running' ? percent(job) : undefined}
				aria-label={m.import_progress_label()}
			></progress>
			<span class="pct" aria-hidden="true">{job.status === 'running' ? pct(percent(job)) : ''}</span
			>
		</div>
		<dl class="counts">
			{#each counts as c (c.label)}
				<div>
					<dt>{c.label}</dt>
					<dd>{num(c.value)}</dd>
				</div>
			{/each}
		</dl>
		<p class="muted">{m.import_progress_note()}</p>
		<div class="actions">
			<Button variant="secondary" onclick={() => (confirmCancel = true)}>{m.import_cancel()}</Button
			>
		</div>
	</section>
{:else if step === 'report' && job}
	<section class="card" aria-labelledby="report-heading">
		<h2 id="report-heading">{m.import_report_heading()}</h2>
		{#if job.status === 'done'}
			<Alert tone="success">{m.import_report_done()} {m.import_report_where()}</Alert>
		{:else if job.status === 'cancelled'}
			<Alert tone="info">{m.import_report_cancelled()}</Alert>
		{:else}
			<Alert>{m.import_report_failed({ reason: errorLabel(job.error ?? '') })}</Alert>
		{/if}
		<dl class="counts">
			{#each counts as c (c.label)}
				<div>
					<dt>{c.label}</dt>
					<dd>{num(c.value)}</dd>
				</div>
			{/each}
		</dl>
		{#if job.undated}<p class="muted">{m.import_report_undated()}</p>{/if}
		{#if job.failures?.length}
			<h3>{m.import_failures_heading()}</h3>
			<table class="data-table">
				<thead>
					<tr
						><th scope="col">{m.import_failures_file()}</th><th scope="col"
							>{m.import_failures_reason()}</th
						></tr
					>
				</thead>
				<tbody>
					{#each job.failures.slice(0, SHOWN_FAILURES) as f, i (i)}
						<tr><td class="name"><bdi>{f.path}</bdi></td><td>{reasonLabel(f.reason)}</td></tr>
					{/each}
				</tbody>
			</table>
			{#if job.failed > SHOWN_FAILURES}
				<p class="muted">{m.import_failures_more({ count: num(job.failed - SHOWN_FAILURES) })}</p>
			{/if}
			<Button variant="secondary" onclick={downloadCsv}>{m.import_failures_csv()}</Button>
		{/if}
		<div class="actions">
			<Button variant="ghost" onclick={again}>{m.import_again()}</Button>
			<a class="primary-link" href={resolve('/(app)/photos')}>{m.import_view_photos()}</a>
		</div>
	</section>
{/if}

<Dialog bind:open={confirmCancel} title={m.import_cancel_title()}>
	<p class="confirm">{m.import_cancel_body()}</p>
	<div class="actions">
		<Button variant="ghost" onclick={() => (confirmCancel = false)}>{m.import_cancel_keep()}</Button
		>
		<Button variant="danger" onclick={cancel} loading={cancelling}
			>{m.import_cancel_confirm()}</Button
		>
	</div>
</Dialog>

<style>
	.back {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		min-height: 2.75rem;
		margin-inline-start: calc(-1 * var(--space-2));
		padding: 0 var(--space-2);
		border-radius: var(--radius-sm);
		color: var(--color-text-muted);
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		text-decoration: none;
	}
	.back:hover {
		color: var(--color-text);
		background: color-mix(in srgb, var(--color-text) 6%, transparent);
	}
	.intro {
		max-width: 44rem;
		margin: var(--space-2) 0 var(--space-5);
		color: var(--color-text-muted);
	}
	.steps {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2) var(--space-5);
		margin: 0 0 var(--space-5);
		padding: 0;
		list-style: none;
		font-size: var(--text-sm);
		color: var(--color-text-muted);
	}
	.steps li {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}
	.dot {
		display: grid;
		place-items: center;
		width: var(--space-5);
		height: var(--space-5);
		border: 1px solid var(--color-border-strong);
		border-radius: var(--radius-full);
		font-size: var(--text-xs);
		font-variant-numeric: tabular-nums;
	}
	.steps .current {
		color: var(--color-text);
		font-weight: var(--weight-medium);
	}
	.steps .current .dot {
		border-color: var(--color-accent);
		background: var(--color-accent);
		color: var(--color-accent-contrast);
	}
	.steps .past .dot {
		border-color: var(--color-accent);
		color: var(--color-accent);
	}
	.card {
		display: grid;
		justify-items: start;
		gap: var(--space-4);
		max-width: 48rem;
		padding: var(--space-6);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-xl);
		background: var(--color-surface);
		box-shadow: var(--shadow-sm);
	}
	.card > :global(*) {
		margin: 0;
	}
	.card > :global(.alert) {
		justify-self: stretch;
	}
	@media (max-width: 600px) {
		.card {
			padding: var(--space-4);
		}
		.step-label {
			display: none;
		}
		.steps .current .step-label {
			display: inline;
		}
	}
	.skeleton {
		min-height: calc(var(--space-8) * 4);
		background: var(--color-surface-sunken);
		box-shadow: none;
	}
	h2 {
		font-size: var(--text-xl);
	}
	h3 {
		font-size: var(--text-md);
		font-family: var(--font-sans);
		font-weight: var(--weight-semibold);
	}
	.muted {
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}
	.takeout-link,
	.primary-link {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		min-height: 2.75rem;
		padding: var(--space-2) var(--space-4);
		border-radius: var(--radius-md);
		font-weight: var(--weight-medium);
		text-decoration: none;
	}
	.takeout-link {
		border: 1px solid var(--color-border-strong);
		color: var(--color-text);
	}
	.takeout-link:hover {
		background: color-mix(in srgb, var(--color-text) 5%, transparent);
	}
	.primary-link {
		background: var(--color-accent);
		color: var(--color-accent-contrast);
	}
	.primary-link:hover {
		background: var(--color-accent-hover);
	}
	.checks {
		display: grid;
		gap: var(--space-2);
		padding: 0;
		list-style: none;
	}
	.checks li {
		display: flex;
		gap: var(--space-2);
		align-items: flex-start;
	}
	.checks :global(svg) {
		flex: none;
		margin-top: var(--space-1);
		color: var(--color-accent);
	}
	.segmented {
		display: inline-flex;
		gap: var(--space-1);
		padding: var(--space-1);
		border-radius: var(--radius-md);
		background: var(--color-surface-sunken);
	}
	.segmented button {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		min-height: 2.75rem;
		padding: 0 var(--space-4);
		border: 0;
		border-radius: var(--radius-sm);
		background: transparent;
		color: var(--color-text-muted);
		font: inherit;
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
		cursor: pointer;
	}
	.segmented button[aria-checked='true'] {
		background: var(--color-surface);
		color: var(--color-text);
		box-shadow: var(--shadow-sm);
	}
	.files {
		display: grid;
		gap: var(--space-3);
		width: 100%;
		padding: 0;
		list-style: none;
	}
	.file-head {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		font-size: var(--text-sm);
	}
	.name {
		unicode-bidi: isolate;
		flex: 1;
		min-width: 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.file-head input {
		width: var(--space-4);
		height: var(--space-4);
		accent-color: var(--color-accent);
	}
	td.name {
		unicode-bidi: isolate;
		white-space: normal;
		overflow-wrap: anywhere;
	}
	.file-status {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
		color: var(--color-text-muted);
		font-variant-numeric: tabular-nums;
	}
	.file-status.error {
		color: var(--color-danger);
	}
	.picks label {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		min-height: 2.75rem;
		padding: 0 var(--space-3);
		border: 1px solid var(--color-border);
		border-radius: var(--radius-md);
		cursor: pointer;
	}
	.picks label:has(input:checked) {
		border-color: var(--color-accent);
		background: var(--color-accent-subtle);
	}
	.picks input {
		width: var(--space-4);
		height: var(--space-4);
		accent-color: var(--color-accent);
	}
	.path {
		max-width: 100%;
		padding: var(--space-2) var(--space-3);
		overflow-wrap: anywhere;
		border-radius: var(--radius-sm);
		background: var(--color-surface-sunken);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
	}
	.field {
		display: grid;
		gap: var(--space-1);
		width: min(100%, 24rem);
		font-size: var(--text-sm);
		font-weight: var(--weight-medium);
	}
	.icon-btn {
		display: grid;
		place-items: center;
		width: 2.75rem;
		height: 2.75rem;
		border: 0;
		border-radius: var(--radius-md);
		background: transparent;
		color: var(--color-text-muted);
		cursor: pointer;
	}
	.icon-btn:hover {
		color: var(--color-text);
		background: color-mix(in srgb, var(--color-text) 6%, transparent);
	}
	progress {
		width: 100%;
		height: var(--space-1);
		appearance: none;
		border: 0;
		border-radius: var(--radius-full);
		background: var(--color-surface-sunken);
		overflow: hidden;
	}
	progress.big {
		height: var(--space-2);
	}
	progress::-webkit-progress-bar {
		background: var(--color-surface-sunken);
	}
	progress::-webkit-progress-value {
		background: var(--color-accent);
		transition: width var(--duration-base) var(--ease-standard);
	}
	progress::-moz-progress-bar {
		background: var(--color-accent);
	}
	.bar {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		width: 100%;
	}
	.pct {
		min-width: 3.5em;
		text-align: end;
		font-variant-numeric: tabular-nums;
		font-size: var(--text-sm);
		color: var(--color-text-muted);
	}
	.status-line {
		font-variant-numeric: tabular-nums;
	}
	.counts {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(8.5rem, 1fr));
		gap: var(--space-3);
		width: 100%;
	}
	.counts div {
		padding: var(--space-3) var(--space-4);
		border-radius: var(--radius-lg);
		background: var(--color-surface-sunken);
	}
	.counts dt {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
	}
	.counts dd {
		margin: 0;
		font-family: var(--font-display);
		font-size: var(--text-2xl);
		font-variant-numeric: tabular-nums;
	}
	.actions {
		display: flex;
		flex-wrap: wrap;
		justify-content: flex-end;
		gap: var(--space-2);
		width: 100%;
	}
	.confirm {
		margin: 0 0 var(--space-5);
		color: var(--color-text-muted);
	}
	.data-table {
		width: 100%;
	}
</style>
