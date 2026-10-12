#!/usr/bin/env bash
# Cuts a release: bumps every package version, commits, tags.
#   make release V=0.6.0
# Requires a CHANGELOG section "## [0.6.0] - YYYY-MM-DD" and a devlog
# docs/devlog/YYYY-MM-DD-v0.6.0.md. The only uncommitted changes allowed are
# CHANGELOG.md and docs/devlog/ (they go into the release commit).
set -euo pipefail
cd "$(dirname "$0")/.."

V="${1:-}"
die() { echo "release: $*" >&2; exit 1; }

[[ "$V" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "usage: make release V=X.Y.Z"
git rev-parse "v$V" >/dev/null 2>&1 && die "tag v$V already exists"
[[ "$(git branch --show-current)" == "main" ]] || die "release from main"
grep -q "^## \[$V\] - [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" CHANGELOG.md || die "CHANGELOG.md has no '## [$V] - YYYY-MM-DD' section"
compgen -G "docs/devlog/*-v$V.md" >/dev/null || die "missing docs/devlog/YYYY-MM-DD-v$V.md"
dirty=$(git status --porcelain | grep -vE '^.. (CHANGELOG\.md|docs/devlog/)' || true)
[[ -z "$dirty" ]] || die "uncommitted changes outside CHANGELOG/devlog:\n$dirty"

# npm packages
for pkg in package.json web/package.json packages/*/package.json; do
	node -e '
		const fs = require("fs"); const [file, v] = process.argv.slice(1);
		const p = JSON.parse(fs.readFileSync(file, "utf8"));
		p.version = v;
		fs.writeFileSync(file, JSON.stringify(p, null, file.startsWith("web/") ? "\t" : 2) + "\n");
	' "$pkg" "$V"
done

# Flutter: version X.Y.Z+build, build number always increases (store requirement)
build=$(sed -n 's/^version: .*+\([0-9]*\)$/\1/p' mobile/pubspec.yaml)
sed -i.bak "s/^version: .*/version: $V+$((build + 1))/" mobile/pubspec.yaml && rm mobile/pubspec.yaml.bak
sed -i.bak "s/^const kAppVersion = .*/const kAppVersion = '$V';/" mobile/lib/core/version.dart && rm mobile/lib/core/version.dart.bak

git add CHANGELOG.md docs/devlog package.json web/package.json packages/*/package.json mobile/pubspec.yaml mobile/lib/core/version.dart
git commit -m "chore(release): v$V"
notes=$(awk -v v="$V" '$0 ~ "^## \\[" v "\\]" {f=1; next} /^## \[/ {f=0} f' CHANGELOG.md)
git tag -a "v$V" -m "Alcove v$V" -m "$notes"
echo "Tagged v$V. Publish with: git push --follow-tags"
