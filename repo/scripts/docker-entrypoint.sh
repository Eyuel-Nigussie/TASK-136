#!/bin/bash
set -euo pipefail

ACTION="${1:-help}"

HOST="host.docker.internal"
SSH_KEY="/app/.docker-ssh-key"

# ─────────────────────────────────────────────────────────────
# Auto-setup: generate SSH key, write config, verify connection.
# Runs every time but only does work on first invocation.
# ─────────────────────────────────────────────────────────────

ensure_ready() {
    local USER="${HOST_USER:-$(cat /app/.docker-host-user 2>/dev/null || echo "")}"
    local PROJECT="${HOST_PROJECT_PATH:-$(cat /app/.docker-host-path 2>/dev/null || echo "")}"

    # ── Platform check ──
    # host.docker.internal only resolves on Docker Desktop (macOS / Windows).
    # If unreachable, the host is not macOS.
    if ! getent hosts "${HOST}" &>/dev/null; then
        echo ""
        echo "This is a native iOS app that requires macOS with Xcode to build and run."
        echo "Docker Desktop for Mac is required — the container delegates to the host"
        echo "Mac's Xcode toolchain via SSH."
        echo ""
        echo "Detected: non-macOS Docker host (host.docker.internal not reachable)."
        exit 0
    fi

    # ── Resolve host user and project path ──
    if [[ -z "${USER}" || -z "${PROJECT}" ]]; then
        echo "ERROR: Could not determine macOS host user or project path."
        echo ""
        echo "Make sure you run via docker compose (not docker run directly):"
        echo "  docker compose run build"
        exit 1
    fi

    # Persist for subsequent runs (survives env var absence)
    echo "${USER}" > /app/.docker-host-user
    echo "${PROJECT}" > /app/.docker-host-path

    # ── Generate SSH key if missing ──
    if [[ ! -f "${SSH_KEY}" ]]; then
        echo "  Auto-setup: generating SSH key..."
        ssh-keygen -t ed25519 -f "${SSH_KEY}" -N "" -C "couriermatch-docker" -q
        chmod 600 "${SSH_KEY}"
        echo "  Key generated at .docker-ssh-key"
        echo ""
    fi

    # ── Test SSH connection ──
    local SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5 -i ${SSH_KEY}"

    if ssh ${SSH_OPTS} "${USER}@${HOST}" "true" &>/dev/null; then
        return 0  # SSH works — ready to go
    fi

    # SSH failed — first-time setup needed on host
    echo ""
    echo "Cannot connect to macOS host (${USER}@${HOST})."
    echo ""
    echo "One-time setup — run these two commands on your Mac:"
    echo ""
    echo "  sudo systemsetup -setremotelogin on"
    echo "  mkdir -p ~/.ssh && cat $(cd /app && pwd)/.docker-ssh-key.pub >> ~/.ssh/authorized_keys"
    echo ""
    echo "Then retry:  docker compose run build"
    echo ""
    exit 1
}

ssh_run() {
    local USER="${HOST_USER:-$(cat /app/.docker-host-user 2>/dev/null || echo "")}"
    local PROJECT="${HOST_PROJECT_PATH:-$(cat /app/.docker-host-path 2>/dev/null || echo "")}"
    local SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i ${SSH_KEY}"

    ssh ${SSH_OPTS} "${USER}@${HOST}" \
        "export PATH=\"/opt/homebrew/bin:/usr/local/bin:\$PATH\" && cd '${PROJECT}' && $1"
}

# ─────────────────────────────────────────────────────────────
case "${ACTION}" in
    help)
        echo ""
        echo "CourierMatch iOS — Docker CLI"
        echo ""
        echo "Usage:"
        echo "  docker compose run build       Build and launch app on iOS Simulator"
        echo "  docker compose run run-mac     Alias for build"
        echo "  docker compose run test-mac    Run full XCTest suite on host Mac"
        echo ""
        echo "  help                           Show this message"
        echo ""
        ;;

    build)
        echo ""
        echo "=== CourierMatch — Build & Launch ==="
        echo ""
        ensure_ready
        echo "  Building and launching on macOS host..."
        echo ""
        ssh_run "make setup && make run"
        ;;

    test-mac)
        echo ""
        echo "=== CourierMatch — XCTest Suite ==="
        echo ""
        ensure_ready
        echo "  Running tests on macOS host..."
        echo ""
        ssh_run "make setup && make test"
        ;;

    *)
        echo "Unknown command: ${ACTION}"
        echo ""
        echo "Available commands:"
        echo "  docker compose run build       Build + launch"
        echo "  docker compose run test-mac    Run tests"
        exit 1
        ;;
esac
