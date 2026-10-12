#!/usr/bin/env bash
# Builds a self-contained ffmpeg for native Linux installs (ADR 0017) from Alpine's packages, the
# same ffmpeg as the Docker image. It carries its own libraries and musl loader, so it runs on any
# Linux distribution whatever its own ffmpeg version.
#   scripts/ffmpeg-bundle.sh amd64|arm64|armv7 [outdir]   → <outdir>/ffmpeg_linux_<arch>.tar.gz
# Needs Docker (with QEMU/binfmt for foreign architectures).
set -euo pipefail
cd "$(dirname "$0")/.."
ARCH="${1:?usage: scripts/ffmpeg-bundle.sh amd64|arm64|armv7 [outdir]}"
OUT="$(mkdir -p "${2:-dist}" && cd "${2:-dist}" && pwd)"
case "$ARCH" in
	amd64) PLATFORM=linux/amd64 ;;
	arm64) PLATFORM=linux/arm64 ;;
	armv7) PLATFORM=linux/arm/v7 ;;
	*) echo "unknown arch $ARCH" >&2; exit 1 ;;
esac
ALPINE=alpine:3.24

docker run --rm --platform "$PLATFORM" -v "$OUT":/out -e ARCH="$ARCH" "$ALPINE" sh -euc '
	apk add --no-cache ffmpeg >/dev/null
	B=/tmp/ffmpeg && mkdir -p $B/bin $B/lib $B/libexec
	cp /usr/bin/ffmpeg /usr/bin/ffprobe $B/libexec/
	loader=$(basename /lib/ld-musl-*.so.1)
	cp -L /lib/$loader $B/lib/
	# Every shared library both programs need, symlinks resolved.
	for exe in /usr/bin/ffmpeg /usr/bin/ffprobe; do
		ldd $exe | awk "/=>/ {print \$3}"
	done | sort -u | while read -r lib; do
		[ "$(basename $lib)" = "$loader" ] || cp -L "$lib" $B/lib/
	done
	for exe in ffmpeg ffprobe; do
		cat > $B/bin/$exe <<WRAP
#!/bin/sh
d=\$(cd "\$(dirname "\$0")/.." && pwd)
exec "\$d/lib/$loader" --library-path "\$d/lib" "\$d/libexec/$exe" "\$@"
WRAP
		chmod 755 $B/bin/$exe
	done
	{
		echo "ffmpeg for Alcove native installs, linux/$ARCH."
		echo "Built from Alpine Linux $(cat /etc/alpine-release) packages, unmodified."
		echo
		echo "ffmpeg and the libraries below are free software under their own licenses (GPL-2.0-or-later,"
		echo "LGPL and others). Sources: https://gitlab.alpinelinux.org/alpine/aports (tag v$(cut -d. -f1,2 /etc/alpine-release)),"
		echo "https://ffmpeg.org/download.html. The Alcove maintainers will also provide the exact"
		echo "source code on request for three years after this release."
		echo
		echo "Packages:"
		apk info -v 2>/dev/null | sort
	} > $B/README.txt
	$B/bin/ffmpeg -hide_banner -version | head -1
	tar -C /tmp -czf /out/ffmpeg_linux_$ARCH.tar.gz ffmpeg
'
ls -lh "$OUT/ffmpeg_linux_$ARCH.tar.gz"
