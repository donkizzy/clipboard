#!/usr/bin/env bash
# Runs the UI tests (demo mode). macOS must allow UI automation: the first
# run may ask you to authorise it, or run once:
#   sudo automationmodetool enable-automationmode-without-authentication
set -euo pipefail
cd "$(dirname "$0")/.."
exec ./scripts/test.sh -only-testing:ClipboardUITests "$@"
