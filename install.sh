#!/bin/sh
# Alcove installer: downloads the right binary, verifies it, runs "alcove install".
#   curl -fsSL https://github.com/Paul-Carouge/Alcove/releases/latest/download/install.sh | sh
# Options are passed to "alcove install", e.g.:
#   curl -fsSL …/install.sh | sh -s -- --mode public --domain cloud.example.com --yes
# Environment: ALCOVE_VERSION (default: latest), ALCOVE_DOWNLOAD_URL (mirror, tests).
set -eu

REPO="Paul-Carouge/Alcove"
VERSION="${ALCOVE_VERSION:-latest}"
BASE="${ALCOVE_DOWNLOAD_URL:-https://github.com/$REPO/releases}"

say() { printf '%s\n' "$*"; }
fail() { printf 'alcove-install: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "$1 is required"; }

fetch() { # url dest
	if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
	elif command -v wget >/dev/null 2>&1; then wget -qO "$2" "$1"
	else fail "curl or wget is required"; fi
}

os=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$os" in
	linux|darwin) ;;
	*) fail "unsupported system $os (on Windows, use install.ps1)" ;;
esac
case "$(uname -m)" in
	x86_64|amd64) arch=amd64 ;;
	aarch64|arm64) arch=arm64 ;;
	armv7l|armv7*) arch=armv7 ;;
	*) fail "unsupported CPU $(uname -m)" ;;
esac
need tar

if [ "$VERSION" = latest ]; then
	dl="$BASE/latest/download"
	# Resolve the version from the checksums file name list.
else
	VERSION=${VERSION#v}; dl="$BASE/download/v$VERSION"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM
say "Downloading Alcove for $os/$arch…"
fetch "$dl/SHA256SUMS" "$tmp/SHA256SUMS" || fail "cannot download the release (is the repository public?)"
archive=$(grep -o "alcove_[0-9][^ ]*_${os}_${arch}\.tar\.gz" "$tmp/SHA256SUMS" | head -n1)
[ -n "$archive" ] || fail "no build for $os/$arch in this release"
fetch "$dl/$archive" "$tmp/$archive"

expected=$(grep " $archive\$" "$tmp/SHA256SUMS" | cut -d' ' -f1)
if command -v sha256sum >/dev/null 2>&1; then actual=$(sha256sum "$tmp/$archive" | cut -d' ' -f1)
else actual=$(shasum -a 256 "$tmp/$archive" | cut -d' ' -f1); fi
[ "$expected" = "$actual" ] || fail "checksum mismatch for $archive"
# The signature is verified by "alcove update" for every later update; the
# first download is trusted through HTTPS from GitHub.

tar -xzf "$tmp/$archive" -C "$tmp"
bin=$(find "$tmp" -type f -name alcove | head -n1)
chmod +x "$bin"

# When piped (curl | sh), stdin is the script: read answers from the terminal
# if there is one; otherwise run non-interactively (pass --yes and options).
tty_ok() { [ -t 0 ] && return 1; (exec </dev/tty) 2>/dev/null; }

if [ "$os" = linux ] && [ "$(id -u)" -ne 0 ]; then
	command -v sudo >/dev/null 2>&1 || fail "run this script as root"
	say "Administrator rights are needed to install the service."
	if tty_ok; then exec sudo "$bin" install "$@" </dev/tty; fi
	exec sudo "$bin" install "$@"
fi
if tty_ok; then exec "$bin" install "$@" </dev/tty; fi
exec "$bin" install "$@"
