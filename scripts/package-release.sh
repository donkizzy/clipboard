#!/usr/bin/env bash
# Build a universal archive. Local candidates always use an ad-hoc signature.
set -euo pipefail
cd "$(dirname "$0")/.."
mode=${1:-candidate}
case "$mode" in
  candidate) identity=- ;;
  distribution)
    : "${DEVELOPER_ID_APPLICATION:?Set the full Developer ID Application identity}"
    : "${NOTARY_PROFILE:?Set the notarytool keychain profile name}"
    [[ "$DEVELOPER_ID_APPLICATION" == "Developer ID Application: "* ]] || exit 1
    identity="$DEVELOPER_ID_APPLICATION"
    ;;
  *) echo "Usage: $0 [candidate|distribution]" >&2; exit 2 ;;
esac

mkdir -p build/releases
work=$(mktemp -d "$PWD/build/releases/.package.XXXXXX")
trap 'rm -rf "$work"' EXIT
xcodegen generate --quiet
xcodebuild -project Clipboard.xcodeproj -scheme Clipboard -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$work/DerivedData" \
  'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build

app="$work/DerivedData/Build/Products/Release/Clipboard.app"
resources="$app/Contents/Resources"
mkdir -p "$resources/Licenses"
cp LICENSE "$resources/Licenses/Clipboard.txt"
cp "$work/DerivedData/SourcePackages/checkouts/KeyboardShortcuts/license" "$resources/Licenses/KeyboardShortcuts.txt"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
name="Clipboard-$version-macOS"
signing=(--force --options runtime --sign "$identity")
if [[ "$mode" == distribution ]]; then
  signing+=(--timestamp)
else
  name="$name-local-rc"
fi
codesign "${signing[@]}" "$app"
zip="$work/$name.zip"
if [[ "$mode" == distribution ]]; then
  ditto -c -k --keepParent "$app" "$work/submission.zip"
  xcrun notarytool submit "$work/submission.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$app"
fi
ditto -c -k --keepParent "$app" "$zip"
ditto -x -k "$zip" "$work/verify"
restored="$work/verify/Clipboard.app"
lipo "$restored/Contents/MacOS/Clipboard" -verify_arch arm64 x86_64
codesign --verify --deep --strict --all-architectures "$restored"
if [[ "$mode" == distribution ]]; then
  xcrun stapler validate "$restored"
  spctl --assess --type execute --verbose "$restored"
fi
(cd "$work" && shasum -a 256 "$name.zip" > "$name.zip.sha256" && shasum -a 256 -c "$name.zip.sha256")
mv "$zip" "$zip.sha256" build/releases/
echo "Created build/releases/$name.zip"
