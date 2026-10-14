# 0025. Documents: text extraction and OCR shipped like ffmpeg

- Status: Accepted (2026-10-12). Replaces the OCR part of [0007](0007-optional-module-containers.md);
  face recognition keeps that ADR's approach.

## Context

Phase 3 makes documents searchable: PDFs, scans and screenshots. ADR 0007 planned OCR as a separate
container, but since ADR 0014 most installs are native, without Docker, and "simple to self-host" is a core
goal. The user chose to ship the tools the way ffmpeg is shipped (ADR 0016, 0017).

## Decision

- **Tools**: poppler (`pdftotext`, `pdfinfo`, `pdftoppm`, `pdfunite`) for PDFs and **Tesseract** with the French and
  English models for OCR, run as external programs with timeouts, one thread each and bounded output.
- **Distribution**: each release publishes `ocr_linux_{amd64,arm64,armv7}.tar.gz`, built by
  `scripts/ocr-bundle.sh` from unmodified Alpine packages with their libraries and musl loader (about 25 MB,
  55 MB on disk), listed in the signed `SHA256SUMS`. `alcove install` offers it (default yes; `--no-ocr`),
  `alcove update` and the in-app update keep it current, and an administrator can install it from the
  System page (native Linux service). The Docker image includes the same packages. macOS and Windows use
  Homebrew or winget. The bundle lives next to the binary (`<bin dir>/ocr/`) and is put first on `PATH`.
- **What is read**: the text layer of every PDF; text files (`text/plain`, Markdown, CSV); with OCR,
  scanned PDFs (fewer than 40 letters per page in the text layer, first 100 pages rendered at 200 dpi) and
  images **without camera metadata** (screenshots, scans). Camera photos are skipped: a library of 50,000
  photos would keep a small server busy for days for little gain.
- **OCR is on by default** when the tools are installed; administrators can turn it off. PDF text layers
  and text files are always read.
- **Storage and search**: one `documents` record per file (status, method, text up to 1 MB, pages), owner
  read-only, written by one background worker. A SQLite **FTS5** table (`unicode61 remove_diacritics 2`)
  indexes name and text; `GET /api/v1/search` returns name matches (substring) then content matches (every
  word as a prefix, best first) with highlighted snippets, never interpreting user input as FTS syntax.

- **Searchable copies** (v0.23): on request, a scan becomes `<name> (OCR).pdf` next to it: each page
  rendered as JPEG and laid out by Tesseract's PDF renderer with invisible text, pages joined by
  `pdfunite`. One job at a time, progress kept in memory (`/api/v1/documents/{id}/searchable`).

## Consequences

- ✅ Searching scans works on every install type, with nothing to configure and nothing leaving the server.
- ✅ Same signed delivery and update path as the binary and ffmpeg.
- ⚠️ Text is stored twice (record and index), a small fraction of the documents themselves.
- ⚠️ OCR is CPU-heavy: one document at a time, one thread; a Raspberry Pi reads a page in several seconds.
- ⚠️ We redistribute GPL software (poppler): the bundle README names the packages and sources, and the
  maintainers provide the corresponding source on request.
- Photos of documents taken with a phone camera are not read unless they are saved as PDFs (scanner apps).
