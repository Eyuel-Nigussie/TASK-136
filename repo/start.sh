#!/bin/bash
set -euo pipefail

echo "=== CourierMatch — Start App ==="
echo ""

# This is a native iOS project — the simulator requires macOS with Xcode.
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Platform not supported: $(uname)"
    echo ""
    echo "Running the app requires macOS with Xcode 16+ and XcodeGen installed."
    echo "The iOS Simulator is only available on macOS."
    exit 0
fi

# Launch the app locally on the iOS Simulator.
cd "$(dirname "$0")"
./scripts/run.sh
