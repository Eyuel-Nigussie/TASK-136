#!/bin/bash
set -euo pipefail

echo "=== CourierMatch — Running Tests ==="
echo ""

# Run tests locally on macOS via the test script.
# Pass an optional suite argument: all (default), unit, integration, ui
cd "$(dirname "$0")"
./scripts/test.sh "${1:-all}"
