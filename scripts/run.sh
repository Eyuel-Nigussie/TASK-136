#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

SIMULATOR="${SIMULATOR:-iPhone 17 Pro}"
BUNDLE_ID="com.eaglepoint.couriermatch"

echo "=== Building & Launching CourierMatch ==="

# Build
./scripts/build.sh

# Find the built .app
APP=$(find ~/Library/Developer/Xcode/DerivedData \
    -name "CourierMatch.app" \
    -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -1)

if [[ -z "$APP" ]]; then
    echo "ERROR: Could not find built .app bundle."
    exit 1
fi

echo "  App bundle: $APP"

# Boot simulator
xcrun simctl boot "${SIMULATOR}" 2>/dev/null || true

# Install and launch
xcrun simctl install "${SIMULATOR}" "$APP"
xcrun simctl launch "${SIMULATOR}" "$BUNDLE_ID"

# Open Simulator.app
open -a Simulator

echo "=== CourierMatch launched on ${SIMULATOR} ==="
