#!/bin/bash
set -euo pipefail

echo "=== CourierMatch — Running Tests ==="
echo ""

# This is a native iOS project — XCTest requires macOS with Xcode.
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Platform not supported: $(uname)"
    echo ""
    echo "Running tests requires macOS with Xcode 16+ and XcodeGen installed."
    echo "XCTest cannot run on Linux or Windows."
    exit 0
fi

# Run tests locally on macOS via the test script.
# Pass an optional suite argument: all (default), unit, integration, ui
cd "$(dirname "$0")"
./scripts/test.sh "${1:-all}"
