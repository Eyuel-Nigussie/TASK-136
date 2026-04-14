#!/bin/bash
set -euo pipefail

# CourierMatch Docker Setup
#
# This configures Docker to SSH back to your Mac host to run xcodebuild.
# Run this once before using `docker run couriermatch build`.

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo ""
echo "=== CourierMatch Docker Setup ==="
echo ""

# ─── Step 1: Enable Remote Login (SSH) ───
echo "Step 1: Checking Remote Login (SSH)..."
SSH_STATUS=$(sudo systemsetup -getremotelogin 2>/dev/null | grep -i "on" || echo "")
if [[ -z "${SSH_STATUS}" ]]; then
    echo "  Remote Login is OFF. Enabling it now..."
    sudo systemsetup -setremotelogin on
    echo "  Remote Login enabled."
else
    echo "  Remote Login is already ON."
fi
echo ""

# ─── Step 2: Generate SSH key for Docker ───
SSH_KEY="${REPO_DIR}/.docker-ssh-key"
echo "Step 2: Generating SSH key for Docker..."
if [[ -f "${SSH_KEY}" ]]; then
    echo "  Key already exists at ${SSH_KEY}"
else
    ssh-keygen -t ed25519 -f "${SSH_KEY}" -N "" -C "couriermatch-docker"
    echo "  Generated ${SSH_KEY}"
fi
echo ""

# ─── Step 3: Authorize the key ───
PUB_KEY="${SSH_KEY}.pub"
AUTH_KEYS="${HOME}/.ssh/authorized_keys"
echo "Step 3: Authorizing SSH key..."
mkdir -p "${HOME}/.ssh"
touch "${AUTH_KEYS}"
chmod 600 "${AUTH_KEYS}"
if grep -q "couriermatch-docker" "${AUTH_KEYS}" 2>/dev/null; then
    echo "  Key already authorized."
else
    cat "${PUB_KEY}" >> "${AUTH_KEYS}"
    echo "  Key added to ${AUTH_KEYS}"
fi
echo ""

# ─── Step 4: Write config for Docker ───
HOST_USER="$(whoami)"
HOST_PROJECT_PATH="${REPO_DIR}"

echo "${HOST_USER}" > "${REPO_DIR}/.docker-host-user"
echo "${HOST_PROJECT_PATH}" > "${REPO_DIR}/.docker-host-path"

echo "Step 4: Configuration saved."
echo "  Host user: ${HOST_USER}"
echo "  Project path: ${HOST_PROJECT_PATH}"
echo ""

# ─── Step 5: Test SSH connection ───
echo "Step 5: Testing SSH connection to host.docker.internal..."
echo "  (This tests from the host directly — Docker will use host.docker.internal)"
ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR -i "${SSH_KEY}" \
    "${HOST_USER}@localhost" "echo 'SSH connection successful'" 2>/dev/null && \
    echo "  Connection OK." || \
    echo "  WARNING: SSH test failed. Ensure Remote Login is enabled in System Settings > General > Sharing."
echo ""

# ─── Step 6: Build Docker image ───
echo "Step 6: Building Docker image..."
cd "${REPO_DIR}"
docker build -t couriermatch . 2>&1 | tail -3
echo ""

echo "=== Setup Complete ==="
echo ""
echo "You can now run:"
echo "  docker run couriermatch build"
echo "  docker run couriermatch test"
echo "  docker run couriermatch test-unit"
echo "  docker run couriermatch test-integration"
echo "  docker run couriermatch run"
echo "  docker run couriermatch help"
echo ""
