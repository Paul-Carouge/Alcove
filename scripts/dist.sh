#!/usr/bin/env bash
# Builds release archives for every platform into dist/, plus SHA256SUMS
# (and SHA256SUMS.sig when ALCOVE_SIGNING_KEY is set).
#   scripts/dist.sh 0.9.0
# FFMPEG_BUNDLES=1 also builds the Linux ffmpeg bundles (needs Docker with QEMU, ADR 0017).
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?usage: scripts/dist.sh X.Y.Z}"
PKG=github.com/Paul-Carouge/Alcove/server/internal/buildinfo
LDFLAGS="-s -w -X ${PKG}.Version=${VERSION}"
TARGETS="linux/amd64 linux/arm64 linux/armv7 darwin/amd64 darwin/arm64 windows/amd64"

# The web UI is embedded in every binary.
if [ -z "${SKIP_WEB:-}" ]; then
	pnpm --filter @alcove/web build >/dev/null
	find server/internal/webui/dist -mindepth 1 ! -name .gitkeep -delete
	cp -R web/build/. server/internal/webui/dist/
fi

rm -rf dist && mkdir -p dist
for target in $TARGETS; do
	os=${target%/*}; arch=${target#*/}
	goarch=$arch; goarm=""
	if [ "$arch" = "armv7" ]; then goarch=arm; goarm=7; fi
	exe=alcove; [ "$os" = windows ] && exe=alcove.exe
	stage="dist/alcove_${VERSION}_${os}_${arch}"
	mkdir -p "$stage"
	(cd server && CGO_ENABLED=0 GOOS=$os GOARCH=$goarch GOARM=$goarm \
		go build -trimpath -ldflags "$LDFLAGS" -o "../$stage/$exe" .)
	cp LICENSE README.md "$stage/"
	if [ "$os" = windows ]; then
		(cd dist && zip -qr "$(basename "$stage").zip" "$(basename "$stage")")
	else
		tar -C dist -czf "$stage.tar.gz" "$(basename "$stage")"
	fi
	rm -rf "$stage"
	echo "built $stage"
done

if [ -n "${FFMPEG_BUNDLES:-}" ]; then
	for arch in amd64 arm64 armv7; do scripts/ffmpeg-bundle.sh "$arch" dist; done
fi

(cd dist && shopt -s nullglob && files=(alcove_* ffmpeg_*) &&
	{ command -v sha256sum >/dev/null && sha256sum "${files[@]}" || shasum -a 256 "${files[@]}"; } > SHA256SUMS)
if [ -n "${ALCOVE_SIGNING_KEY:-}" ]; then
	(cd server && go run ./tools/sign ../dist/SHA256SUMS)
	echo "signed dist/SHA256SUMS"
fi
cp install.sh install.ps1 dist/ 2>/dev/null || true
