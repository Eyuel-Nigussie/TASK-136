#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

ACTION="${1:-help}"

# Check if we're on macOS with Xcode available
if [[ "$(uname)" != "Darwin" ]] || ! command -v xcodebuild &>/dev/null; then
    echo ""
    echo "=== CourierMatch iOS ==="
    echo ""
    echo "iOS apps require macOS + Xcode to build, test, and run."
    echo "This container does not have access to the Xcode toolchain."
    echo ""
    echo "To use Docker, run on a macOS host with Xcode installed:"
    echo "  docker run -v /Applications/Xcode.app:/Applications/Xcode.app couriermatch build"
    echo ""
    echo "Or run directly on macOS without Docker:"
    echo "  make setup       # generate .xcodeproj"
    echo "  make build       # build for iOS Simulator"
    echo "  make test        # run all 299 tests"
    echo "  make run         # launch on simulator"
    echo ""
    echo "For CI, use macOS runners:"
    echo "  GitHub Actions:  runs-on: macos-latest"
    echo "  Xcode Cloud:     developer.apple.com/xcode-cloud"
    echo ""
    exit 1
fi

case "${ACTION}" in
    bootstrap)
        ./scripts/bootstrap.sh
        ;;
    build)
        ./scripts/build.sh
        ;;
    test)
        ./scripts/test.sh all
        ;;
    test-unit)
        ./scripts/test.sh unit
        ;;
    test-integration)
        ./scripts/test.sh integration
        ;;
    test-ui)
        ./scripts/test.sh ui
        ;;
    run)
        ./scripts/run.sh
        ;;
    help|*)
        echo ""
        echo "=== CourierMatch iOS ==="
        echo ""
        echo "Commands:"
        echo "  docker run couriermatch build             Build for iOS Simulator"
        echo "  docker run couriermatch test              Run all tests"
        echo "  docker run couriermatch test-unit         Run unit tests only"
        echo "  docker run couriermatch test-integration  Run integration tests only"
        echo "  docker run couriermatch test-ui           Run UI tests"
        echo "  docker run couriermatch run               Build + launch on simulator"
        echo "  docker run couriermatch bootstrap         Install deps + generate project"
        echo "  docker run couriermatch help              Show this message"
        echo ""
        echo "Requires macOS host with Xcode installed."
        echo ""
        ;;
esac
