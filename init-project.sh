#!/bin/bash

# Master initialization script
# Run this once to set up the entire project structure
#
# Usage:
#   ./init-project.sh                    # Auto-detect: Quadlets on Linux+systemd, compose elsewhere
#   ./init-project.sh --runtime=quadlets # Force Podman Quadlets (Linux + systemd only)
#   ./init-project.sh --runtime=compose  # Force compose (Docker or podman-compose)

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

RUNTIME_MODE="detect"
for arg in "$@"; do
    [[ $arg == --runtime=quadlets ]] && RUNTIME_MODE="quadlets"
    [[ $arg == --runtime=compose ]]  && RUNTIME_MODE="compose"
done

if [ "$RUNTIME_MODE" = "detect" ]; then
    # On Linux with an active systemd user session, Quadlets are the recommended
    # production approach. Fall back to compose on macOS or non-systemd hosts.
    if [[ "$(uname -s)" == "Linux" ]] && systemctl --user status &>/dev/null 2>&1; then
        RUNTIME_MODE="quadlets"
    else
        RUNTIME_MODE="compose"
    fi
fi

if [ "$RUNTIME_MODE" = "quadlets" ]; then
    exec "$SCRIPT_DIR/podman/scripts/setup-quadlets.sh"
else
    exec "$SCRIPT_DIR/scripts/setup.sh"
fi
