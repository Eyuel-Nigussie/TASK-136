#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

SIMULATOR="${SIMULATOR:-iPhone 17 Pro}"

echo "=== Building CourierMatch ==="

# Ensure project exists
if [[ ! -d "CourierMatch.xcodeproj" ]]; then
    echo "  Generating Xcode project..."
    xcodegen generate
fi

xcodebuild build \
    -project CourierMatch.xcodeproj \
    -scheme CourierMatch \
    -destination "platform=iOS Simulator,name=${SIMULATOR}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=YES \
    AD_HOC_CODE_SIGNING_ALLOWED=YES \
    GENERATE_INFOPLIST_FILE=YES \
    -quiet

echo "=== BUILD SUCCEEDED ==="
