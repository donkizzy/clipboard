#!/usr/bin/env bash
# Builds and runs the unit tests from the command line.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null && xcodegen generate --quiet
xcodebuild -project Clipboard.xcodeproj -scheme Clipboard -derivedDataPath build/DerivedData \
  -destination 'platform=macOS' test "$@" 2>&1 | tee build/test.log | grep -E "(error|warning):|✘|✔ Test run|Test run with|\*\* TEST" || true
grep -q "\*\* TEST SUCCEEDED \*\*" build/test.log
