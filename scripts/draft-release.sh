#!/usr/bin/env bash
# Build from the existing upstream tag and upload only a notarized distribution.
set -euo pipefail
cd "$(dirname "$0")/.."
tag=${1:?Usage: draft-release.sh vMAJOR.MINOR.PATCH}
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Expected vMAJOR.MINOR.PATCH" >&2; exit 2; }
repo=donkizzy/clipboard
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git clone --quiet --branch "$tag" --depth 1 "https://github.com/$repo.git" "$work/source"
cd "$work/source"
[[ "$(git rev-parse HEAD)" == "$(git rev-parse "refs/tags/$tag^{commit}")" ]]
version=${tag#v}
configured=$(awk '$1 == "MARKETING_VERSION" && $2 == "=" {print $3}' Config/Shared.xcconfig)
[[ "$configured" == "$version" ]] || { echo "Tag and MARKETING_VERSION differ" >&2; exit 1; }
notes="docs/releases/$version.md"
[[ -s "$notes" ]] || { echo "Missing release notes: $notes" >&2; exit 1; }
./scripts/test.sh
./scripts/package-release.sh distribution
asset="build/releases/Clipboard-$version-macOS.zip"
gh release create "$tag" "$asset" "$asset.sha256" --repo "$repo" --verify-tag \
  --draft --title "Clipboard $version" --notes-file "$notes"
