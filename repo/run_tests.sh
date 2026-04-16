#!/bin/bash
set -euo pipefail

echo "=== CourierMatch — Running Tests ==="
echo ""

# Build the Docker image, then run the test suite.
# docker compose passes HOST_USER/HOST_PROJECT_PATH from the host
# environment and mounts the repo volume automatically.
docker compose build --quiet
docker compose run test-mac
