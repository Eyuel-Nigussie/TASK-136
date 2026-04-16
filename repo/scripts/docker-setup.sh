#!/bin/bash
set -euo pipefail

# CourierMatch — One-Time macOS Host Setup
#
# Enables Remote Login (SSH) and authorizes the Docker SSH key so the
# container can delegate builds to the host Mac's Xcode toolchain.
#
# You only need to run this ONCE. After that, `docker compose run build`
# handles everything automatically.

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SSH_KEY="${REPO_DIR}/.docker-ssh-key"
PUB_KEY="${SSH_KEY}.pub"

echo ""
echo "=== CourierMatch — One-Time macOS Setup ==="
echo ""

# ─── Step 1: Enable Remote Login (SSH) ───
echo "[1/3] Checking Remote Login (SSH)..."
SSH_STATUS=$(sudo systemsetup -getremotelogin 2>/dev/null | grep -i "on" || echo "")
if [[ -z "${SSH_STATUS}" ]]; then
    echo "  Enabling Remote Login..."
    sudo systemsetup -setremotelogin on
    echo "  Done."
else
    echo "  Already enabled."
fi
echo ""

# ─── Step 2: Generate SSH key if missing ───
echo "[2/3] Checking SSH key..."
if [[ ! -f "${SSH_KEY}" ]]; then
    echo "  Generating SSH key..."
    ssh-keygen -t ed25519 -f "${SSH_KEY}" -N "" -C "couriermatch-docker"
    echo "  Generated at ${SSH_KEY}"
else
    echo "  Key already exists."
fi
echo ""

# ─── Step 3: Authorize the key ───
AUTH_KEYS="${HOME}/.ssh/authorized_keys"
echo "[3/3] Authorizing SSH key..."
mkdir -p "${HOME}/.ssh"
touch "${AUTH_KEYS}"
chmod 600 "${AUTH_KEYS}"
if grep -q "couriermatch-docker" "${AUTH_KEYS}" 2>/dev/null; then
    echo "  Already authorized."
else
    cat "${PUB_KEY}" >> "${AUTH_KEYS}"
    echo "  Key added to ${AUTH_KEYS}"
fi
echo ""

# ─── Write config for Docker ───
echo "$(whoami)" > "${REPO_DIR}/.docker-host-user"
echo "${REPO_DIR}" > "${REPO_DIR}/.docker-host-path"

# ─── Verify ───
echo "Testing SSH to localhost..."
ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR -i "${SSH_KEY}" \
    "$(whoami)@localhost" "echo 'SSH OK'" 2>/dev/null && \
    echo "  Connection verified." || \
    echo "  WARNING: SSH test failed. Check System Settings > General > Sharing > Remote Login."
echo ""

echo "=== Setup complete ==="
echo ""
echo "You can now run:"
echo "  docker compose run build       # Build + launch on simulator"
echo "  docker compose run test-mac    # Run XCTest suite"
echo ""
