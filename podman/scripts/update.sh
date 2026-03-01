#!/bin/bash

# N8N Update Script (Podman Quadlets)
# Pulls the latest n8n image and performs a rolling restart of all n8n services.
# PostgreSQL and Redis are NOT restarted — only n8n containers are updated.
#
# Usage:
#   ./podman/scripts/update.sh
#   ./podman/scripts/update.sh --image n8nio/n8n:1.75.0   (pin to a specific version)
#
# After updating, verify:
#   systemctl --user is-active n8n-main n8n-worker@1 n8n-worker@2
#   ./podman/scripts/health-check.sh

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PODMAN_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$PODMAN_DIR")"

N8N_IMAGE="n8nio/n8n:latest"

# Parse optional --image flag
while [[ $# -gt 0 ]]; do
    case "$1" in
        --image) N8N_IMAGE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=========================================="
echo "N8N Update — $(date)"
echo "Image: ${N8N_IMAGE}"
echo "=========================================="
echo ""

# Capture current version before update
CURRENT_VERSION=$(podman exec n8n-main n8n --version 2>/dev/null || echo "unknown")
echo "Current version: ${CURRENT_VERSION}"

# Optionally run a backup before updating
echo ""
read -p "Run a backup before updating? [Y/n] " -n 1 -r; echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "Running backup..."
    bash "$SCRIPT_DIR/backup.sh"
    echo ""
fi

# Pull new image
echo "Pulling image: ${N8N_IMAGE} ..."
podman pull "${N8N_IMAGE}"
echo "✓ Image pulled"
echo ""

# Graceful stop: workers first, then main
echo "Stopping workers..."
systemctl --user stop "n8n-worker@1.service" "n8n-worker@2.service" 2>/dev/null || true
echo "  ✓ Workers stopped"

echo "Stopping n8n-main..."
systemctl --user stop n8n-main.service
echo "  ✓ n8n-main stopped"

# Update the image tag in installed quadlet files if pinning to a specific version
if [[ "${N8N_IMAGE}" != "n8nio/n8n:latest" ]]; then
    SYSTEMD_USER_DIR="$HOME/.config/containers/systemd"
    echo "Pinning image to ${N8N_IMAGE} in installed unit files..."
    sed -i "s|Image=n8nio/n8n:.*|Image=${N8N_IMAGE}|g" \
        "$SYSTEMD_USER_DIR/n8n-main.container" \
        "$SYSTEMD_USER_DIR/n8n-worker@.container" 2>/dev/null || true
    systemctl --user daemon-reload
    echo "  ✓ Unit files updated and daemon reloaded"
fi

# Restart n8n services
echo "Starting n8n-main..."
systemctl --user start n8n-main.service
echo "  ✓ n8n-main started"

echo "Starting workers..."
systemctl --user start "n8n-worker@1.service" "n8n-worker@2.service"
echo "  ✓ Workers started"
echo ""

# Wait a moment for n8n to initialize
sleep 5

# Show new version
NEW_VERSION=$(podman exec n8n-main n8n --version 2>/dev/null || echo "unknown")

echo "=========================================="
echo "Update complete!"
echo "  Before: ${CURRENT_VERSION}"
echo "  After:  ${NEW_VERSION}"
echo "=========================================="
echo ""
echo "Verify with:"
echo "  systemctl --user is-active n8n-main 'n8n-worker@1' 'n8n-worker@2'"
echo "  ./podman/scripts/health-check.sh"
echo ""
