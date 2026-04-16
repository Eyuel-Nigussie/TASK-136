#!/bin/bash
set -euo pipefail

echo ""
echo "=== CourierMatch — Docker Build (Validate) ==="
echo ""

cd /app

echo "--- Validating project structure ---"
python3 scripts/validate-build.py
echo ""

echo "--- Validating test coverage ---"
python3 scripts/validate-tests.py
echo ""

echo "=== Build validation complete ==="
