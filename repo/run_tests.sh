#!/bin/bash
set -euo pipefail

echo "=== CourierMatch — Running Tests ==="
echo ""

docker build -t couriermatch . -q
docker run --rm couriermatch test
