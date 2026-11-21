#!/usr/bin/env bash
# Builds and runs the unit tests from the command line (UI tests: see
# scripts/ui-test.sh), then prints the
# totals from the result bundle (Swift Testing's console output is split
# across parallel workers, so it isn't a reliable count).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
command -v xcodegen >/dev/null && xcodegen generate --quiet
rm -rf build/Tests.xcresult
status=0
xcodebuild -project Clipboard.xcodeproj -scheme Clipboard -derivedDataPath build/DerivedData \
  -destination 'platform=macOS' -resultBundlePath build/Tests.xcresult test \
  "${@:--skip-testing:ClipboardUITests}" > build/test.log 2>&1 || status=$?

grep -E "(error|warning): |✘" build/test.log | grep -v appintentsmetadataprocessor || true
if [ -d build/Tests.xcresult ]; then
  xcrun xcresulttool get test-results summary --path build/Tests.xcresult --compact \
    | python3 -c 'import json, sys
s = json.load(sys.stdin)
print("{}: {} passed, {} failed, {} skipped ({} total)".format(
    s["result"], s["passedTests"], s["failedTests"], s["skippedTests"], s["totalTestCount"]))'
fi
[ "$status" -eq 0 ] || { echo "Full log: build/test.log"; exit "$status"; }
