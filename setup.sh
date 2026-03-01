#!/bin/bash

# N8N Deployment Setup
# Requires: Linux + systemd, Podman >= 4.4

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
exec "$SCRIPT_DIR/podman/scripts/setup-quadlets.sh"
