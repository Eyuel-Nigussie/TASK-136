#!/bin/bash
set -euo pipefail

echo "=== CourierMatch Bootstrap ==="

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "ERROR: iOS development requires macOS. Cannot proceed on $(uname)."
    exit 1
fi

# Check Xcode
if ! command -v xcodebuild &>/dev/null; then
    echo "ERROR: Xcode is not installed."
    echo "  Install from: https://developer.apple.com/xcode/"
    exit 1
fi
XCODE_VERSION=$(xcodebuild -version | head -1)
echo "  Found: $XCODE_VERSION"

# Check/install XcodeGen
if ! command -v xcodegen &>/dev/null; then
    echo "  XcodeGen not found. Installing via Homebrew..."
    if ! command -v brew &>/dev/null; then
        echo "ERROR: Homebrew is required to install XcodeGen."
        echo "  Install from: https://brew.sh"
        exit 1
    fi
    brew install xcodegen
fi
echo "  Found: XcodeGen $(xcodegen --version 2>/dev/null || echo 'unknown')"

# Check simulator availability
SIM_COUNT=$(xcrun simctl list devices available 2>/dev/null | grep -ci "iphone" || true)
if [[ "$SIM_COUNT" -eq 0 ]]; then
    echo "WARNING: No iPhone simulators found."
    echo "  Open Xcode > Settings > Platforms to download an iOS Simulator runtime."
fi
echo "  iPhone simulators available: $SIM_COUNT"

# Generate Xcode project
echo ""
echo "=== Generating Xcode Project ==="
cd "$(dirname "$0")/.."
xcodegen generate
echo "  Generated CourierMatch.xcodeproj"

echo ""
echo "=== Bootstrap Complete ==="
echo "  Run: make build    (build the app)"
echo "  Run: make test     (run tests)"
echo "  Run: make run      (launch on simulator)"
