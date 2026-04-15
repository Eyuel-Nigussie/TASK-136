#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

SIMULATOR="${SIMULATOR:-iPhone 17 Pro}"
BUNDLE_ID="com.eaglepoint.couriermatch"

echo "=== Building & Launching CourierMatch ==="

# Build
./scripts/build.sh

# Find the built .app bundle.
#
# Xcode produces two `CourierMatch.app` directories under DerivedData:
#   1. .../Build/Products/Debug-iphonesimulator/CourierMatch.app  ← real build, has Info.plist + bundle ID
#   2. .../Index.noindex/Build/Products/Debug-iphonesimulator/CourierMatch.app  ← symbol-indexing stub, NO Info.plist
#
# The indexer stub has no bundle ID, so `simctl install` fails with
# "Missing bundle ID" if we pick it. Exclude Index.noindex and require
# the canonical Build/Products path.
APP=$(find ~/Library/Developer/Xcode/DerivedData \
    -name "CourierMatch.app" \
    -path "*/Build/Products/Debug-iphonesimulator/*" \
    -not -path "*Index.noindex*" 2>/dev/null | head -1)

if [[ -z "$APP" ]]; then
    echo "ERROR: Could not find built .app bundle (looked under */Build/Products/Debug-iphonesimulator/, excluding Index.noindex)."
    exit 1
fi

# Sanity-check: the bundle must contain an Info.plist with the expected bundle ID.
if [[ ! -f "$APP/Info.plist" ]]; then
    echo "ERROR: $APP/Info.plist is missing — rejecting to avoid 'Missing bundle ID' install failure."
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
