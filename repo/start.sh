#!/bin/bash
set -euo pipefail

echo "=== CourierMatch — Start App ==="
echo ""

# Launch the app locally on the iOS Simulator.
# Requires macOS with Xcode and XcodeGen installed.
cd "$(dirname "$0")"
./scripts/run.sh
