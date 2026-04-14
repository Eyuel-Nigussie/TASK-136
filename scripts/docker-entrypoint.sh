#!/bin/bash
set -euo pipefail

ACTION="${1:-help}"

# ─── Resolve host connection ───
# Docker for Mac exposes the host at host.docker.internal.
# We SSH to the Mac host where Xcode lives to run xcodebuild.
HOST="host.docker.internal"
USER="${HOST_USER:-$(cat /app/.docker-host-user 2>/dev/null || echo "")}"
PROJECT="${HOST_PROJECT_PATH:-$(cat /app/.docker-host-path 2>/dev/null || echo "")}"
SSH_KEY="/app/.docker-ssh-key"

if [[ "${ACTION}" == "help" ]]; then
    echo ""
    echo "CourierMatch iOS — Docker CLI"
    echo ""
    echo "Usage: docker run couriermatch <command>"
    echo ""
    echo "Commands:"
    echo "  build             Build for iOS Simulator"
    echo "  test              Run all 299 tests"
    echo "  test-unit         Run unit tests only"
    echo "  test-integration  Run integration tests only"
    echo "  test-ui           Run UI tests"
    echo "  run               Build + launch on simulator"
    echo "  setup             Generate .xcodeproj"
    echo "  clean             Remove build artifacts"
    echo "  help              Show this message"
    echo ""
    echo "First-time setup:"
    echo "  ./scripts/docker-setup.sh"
    echo ""
    exit 0
fi

# ─── Validate setup ───
if [[ -z "${USER}" ]]; then
    echo "ERROR: HOST_USER not set. Run ./scripts/docker-setup.sh first."
    exit 1
fi
if [[ -z "${PROJECT}" ]]; then
    echo "ERROR: HOST_PROJECT_PATH not set. Run ./scripts/docker-setup.sh first."
    exit 1
fi
if [[ ! -f "${SSH_KEY}" ]]; then
    echo "ERROR: SSH key not found at ${SSH_KEY}. Run ./scripts/docker-setup.sh first."
    exit 1
fi

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i ${SSH_KEY}"

ssh_run() {
    # Source the user's shell profile so brew-installed tools (xcodegen etc.) are on PATH.
    ssh ${SSH_OPTS} "${USER}@${HOST}" "export PATH=\"/opt/homebrew/bin:/usr/local/bin:\$PATH\" && cd '${PROJECT}' && $1"
}

# ─── Map commands to host-side make targets ───
case "${ACTION}" in
    setup)
        echo "=== Generating .xcodeproj ==="
        ssh_run "make setup"
        ;;
    build)
        echo "=== Building CourierMatch ==="
        ssh_run "make setup && make build"
        ;;
    test)
        echo "=== Running All Tests ==="
        ssh_run "make setup && make test"
        ;;
    test-unit)
        echo "=== Running Unit Tests ==="
        ssh_run "make setup && make test-unit"
        ;;
    test-integration)
        echo "=== Running Integration Tests ==="
        ssh_run "make setup && make test-integration"
        ;;
    test-ui)
        echo "=== Running UI Tests ==="
        ssh_run "make setup && make test-ui"
        ;;
    run)
        echo "=== Building & Launching ==="
        ssh_run "make setup && make run"
        ;;
    clean)
        echo "=== Cleaning ==="
        ssh_run "make clean"
        ;;
    *)
        echo "Unknown command: ${ACTION}"
        echo "Run: docker run couriermatch help"
        exit 1
        ;;
esac
