#!/usr/bin/env bash
# Builds a self-contained OCR toolkit for native Linux installs (ADR 0025) from Alpine's packages,
# the same tools as the Docker image: Tesseract with its French and English models, and poppler's
# pdftotext/pdftoppm/pdfinfo/pdfunite. Like the ffmpeg bundle it carries its own libraries and musl loader.
#   scripts/ocr-bundle.sh amd64|arm64|armv7 [outdir]   → <outdir>/ocr_linux_<arch>.tar.gz
# Needs Docker (with QEMU/binfmt for foreign architectures).
set -euo pipefail
cd "$(dirname "$0")/.."
ARCH="${1:?usage: scripts/ocr-bundle.sh amd64|arm64|armv7 [outdir]}"
OUT="$(mkdir -p "${2:-dist}" && cd "${2:-dist}" && pwd)"
case "$ARCH" in
	amd64) PLATFORM=linux/amd64 ;;
	arm64) PLATFORM=linux/arm64 ;;
	armv7) PLATFORM=linux/arm/v7 ;;
	*) echo "unknown arch $ARCH" >&2; exit 1 ;;
esac
ALPINE=alpine:3.24

docker run --rm --platform "$PLATFORM" -v "$OUT":/out -e ARCH="$ARCH" "$ALPINE" sh -euc '
	apk add --no-cache tesseract-ocr tesseract-ocr-data-fra tesseract-ocr-data-eng poppler-utils >/dev/null
	B=/tmp/ocr && mkdir -p $B/bin $B/lib $B/libexec $B/share
	EXES="tesseract pdftotext pdftoppm pdfinfo pdfunite"
	for exe in $EXES; do cp /usr/bin/$exe $B/libexec/; done
	cp -r /usr/share/tessdata $B/share/
	loader=$(basename /lib/ld-musl-*.so.1)
	cp -L /lib/$loader $B/lib/
	for exe in $EXES; do
		ldd /usr/bin/$exe | awk "/=>/ {print \$3}"
	done | sort -u | while read -r lib; do
		[ "$(basename $lib)" = "$loader" ] || cp -L "$lib" $B/lib/
	done
	for exe in $EXES; do
		cat > $B/bin/$exe <<WRAP
#!/bin/sh
d=\$(cd "\$(dirname "\$0")/.." && pwd)
TESSDATA_PREFIX="\$d/share/tessdata" exec "\$d/lib/$loader" --library-path "\$d/lib" "\$d/libexec/$exe" "\$@"
WRAP
		chmod 755 $B/bin/$exe
	done
	{
		echo "OCR tools for Alcove native installs, linux/$ARCH: Tesseract (French and English models) and poppler."
		echo "Built from Alpine Linux $(cat /etc/alpine-release) packages, unmodified."
		echo
		echo "Tesseract (Apache-2.0), its models (Apache-2.0), poppler (GPL-2.0-or-later) and the libraries"
		echo "below are free software under their own licenses. Sources:"
		echo "https://gitlab.alpinelinux.org/alpine/aports (tag v$(cut -d. -f1,2 /etc/alpine-release)),"
		echo "https://github.com/tesseract-ocr, https://poppler.freedesktop.org. The Alcove maintainers will"
		echo "also provide the exact source code on request for three years after this release."
		echo
		echo "Packages:"
		apk info -v 2>/dev/null | sort
	} > $B/README.txt
	$B/bin/tesseract --version 2>&1 | head -1
	$B/bin/tesseract --list-langs 2>&1 | tail -n +2 | tr "\n" " "; echo
	$B/bin/pdftotext -v 2>&1 | head -1
	tar -C /tmp -czf /out/ocr_linux_$ARCH.tar.gz ocr
'
ls -lh "$OUT/ocr_linux_$ARCH.tar.gz"
