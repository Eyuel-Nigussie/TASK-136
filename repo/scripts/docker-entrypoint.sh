#!/bin/bash
set -euo pipefail

ACTION="${1:-help}"

case "${ACTION}" in
    help)
        echo ""
        echo "CourierMatch iOS — Docker CLI"
        echo ""
        echo "Usage: docker run couriermatch <command>"
        echo ""
        echo "Platform-independent (works on Linux):"
        echo "  build             Validate project structure, sources, and configuration"
        echo "  test              Validate tests structure, assertions, and coverage"
        echo ""
        echo "macOS-only (requires Xcode on host):"
        echo "  run-mac           Build and launch app on iOS Simulator (requires ./scripts/docker-setup.sh)"
        echo "  test-mac          Run full XCTest suite on host Mac (requires ./scripts/docker-setup.sh)"
        echo ""
        echo "  help              Show this message"
        echo ""
        ;;

    build)
        echo "=== CourierMatch Build Validation ==="
        echo ""
        python3 /app/scripts/validate-build.py
        ;;

    test)
        echo "=== CourierMatch Test Validation ==="
        echo ""
        python3 /app/scripts/validate-tests.py
        ;;

    run-mac|test-mac)
        HOST="host.docker.internal"
        USER="${HOST_USER:-$(cat /app/.docker-host-user 2>/dev/null || echo "")}"
        PROJECT="${HOST_PROJECT_PATH:-$(cat /app/.docker-host-path 2>/dev/null || echo "")}"
        SSH_KEY="/app/.docker-ssh-key"

        if [[ -z "${USER}" || -z "${PROJECT}" || ! -f "${SSH_KEY}" ]]; then
            echo "ERROR: macOS host not configured."
            echo ""
            echo "Run on your Mac first:"
            echo "  ./scripts/docker-setup.sh"
            echo ""
            echo "Then retry with volume mount:"
            echo "  docker run -v \"\$(pwd):/app\" couriermatch ${ACTION}"
            exit 1
        fi

        SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i ${SSH_KEY}"

        ssh_run() {
            ssh ${SSH_OPTS} "${USER}@${HOST}" "export PATH=\"/opt/homebrew/bin:/usr/local/bin:\$PATH\" && cd '${PROJECT}' && $1"
        }

        if [[ "${ACTION}" == "run-mac" ]]; then
            echo "=== Building & Launching on macOS host ==="
            ssh_run "make setup && make run"
        else
            echo "=== Running XCTest suite on macOS host ==="
            ssh_run "make setup && make test"
        fi
        ;;

    *)
        echo "Unknown command: ${ACTION}"
        echo "Run: docker run couriermatch help"
        exit 1
        ;;
esac
