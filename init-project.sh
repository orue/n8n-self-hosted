#!/bin/bash

# Master initialization script
# Run this once to set up the entire project structure
#
# Usage:
#   ./init-project.sh                    # Auto-detect runtime (Docker or podman-compose)
#   ./init-project.sh --runtime=quadlets # Deploy via Podman Quadlets (Linux + systemd only)

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

RUNTIME_MODE="auto"
for arg in "$@"; do
    [[ $arg == --runtime=quadlets ]] && RUNTIME_MODE="quadlets"
done

if [ "$RUNTIME_MODE" = "quadlets" ]; then
    exec "$SCRIPT_DIR/podman/scripts/setup-quadlets.sh"
else
    exec "$SCRIPT_DIR/scripts/setup.sh"
fi
