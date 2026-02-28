#!/bin/bash

# N8N Quadlet Setup Script
# Deploys N8N using Podman Quadlets (systemd unit files)
# Requires: Linux host with systemd, Podman >= 4.4, rootless Podman configured

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PODMAN_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$PODMAN_DIR")"
QUADLET_SRC="$PODMAN_DIR/quadlets"
SYSTEMD_USER_DIR="$HOME/.config/containers/systemd"

echo "=========================================="
echo "N8N Quadlet Setup"
echo "=========================================="
echo ""

# Verify Podman is available
if ! command -v podman &> /dev/null; then
    echo "Error: Podman is not installed"
    exit 1
fi

# Verify Podman >= 4.4 (Quadlet support)
PODMAN_VERSION=$(podman --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
PODMAN_MAJOR=$(echo "$PODMAN_VERSION" | cut -d. -f1)
PODMAN_MINOR=$(echo "$PODMAN_VERSION" | cut -d. -f2)

if [ "$PODMAN_MAJOR" -lt 4 ] || { [ "$PODMAN_MAJOR" -eq 4 ] && [ "$PODMAN_MINOR" -lt 4 ]; }; then
    echo "Error: Podman >= 4.4 is required for Quadlet support (found $PODMAN_VERSION)"
    exit 1
fi

echo "✓ Podman $PODMAN_VERSION detected"

# Verify systemd user session is available
if ! systemctl --user status &> /dev/null; then
    echo "Error: systemd user session not available. Quadlets require a Linux host with systemd."
    exit 1
fi

echo "✓ systemd user session available"
echo ""

# Verify subuid/subgid for rootless containers
if ! grep -q "^$(id -un):" /etc/subuid 2>/dev/null; then
    echo "Error: No subuid entry for $(id -un)."
    echo "Run: sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $(id -un)"
    exit 1
fi

echo "✓ Rootless Podman configured"

# Create data directories
echo "Creating data directories..."
mkdir -p "$PROJECT_DIR/data/n8n"
mkdir -p "$PROJECT_DIR/data/postgres"
mkdir -p "$PROJECT_DIR/data/redis"
mkdir -p "$PROJECT_DIR/backups"
echo "✓ Directories created"
echo ""

# Check for .env file
if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "Warning: .env file not found"
    if [ -f "$PROJECT_DIR/.env.example" ]; then
        cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
        echo "Created .env from .env.example"
        echo "IMPORTANT: Edit $PROJECT_DIR/.env and set your passwords before continuing"
        echo "Run: nano $PROJECT_DIR/.env"
        exit 0
    else
        echo "Error: .env.example not found"
        exit 1
    fi
fi

chmod 600 "$PROJECT_DIR/.env"

# Validate .env
if grep -q "CHANGE_ME" "$PROJECT_DIR/.env"; then
    echo "Error: Please update all CHANGE_ME values in .env"
    exit 1
fi

echo "✓ .env validated"

# Install Quadlet unit files
echo "Installing Quadlet unit files to $SYSTEMD_USER_DIR..."
mkdir -p "$SYSTEMD_USER_DIR"

for f in "$QUADLET_SRC"/*; do
    fname="$(basename "$f")"
    sed "s|REPO_DIR_PLACEHOLDER|$PROJECT_DIR|g" "$f" > "$SYSTEMD_USER_DIR/$fname"
    echo "  Installed: $fname"
done

echo "✓ Quadlet files installed"
echo ""

# Enable linger so user services survive logout
echo "Enabling linger for $(whoami)..."
loginctl enable-linger "$(whoami)"
echo "✓ Linger enabled"

# Reload systemd user daemon (causes Quadlet generator to run)
echo "Reloading systemd user daemon..."
systemctl --user daemon-reload
echo "✓ Daemon reloaded"
echo ""

# Start services in dependency order
echo "Starting services..."

echo "  Starting n8n-postgres..."
systemctl --user start n8n-postgres.service
echo "  Waiting for PostgreSQL container to start..."
timeout 120 bash -c 'until podman container inspect postgres --format "{{.State.Running}}" 2>/dev/null | grep -q true; do sleep 2; done' \
    || { echo "Error: PostgreSQL container did not start in time"; exit 1; }
echo "  Waiting for PostgreSQL to be healthy..."
timeout 120 bash -c 'until podman healthcheck run postgres &>/dev/null; do sleep 2; done' \
    || { echo "Error: PostgreSQL did not become healthy in time"; exit 1; }
echo "  ✓ PostgreSQL ready"

echo "  Starting n8n-redis..."
systemctl --user start n8n-redis.service
echo "  Waiting for Redis container to start..."
timeout 60 bash -c 'until podman container inspect redis --format "{{.State.Running}}" 2>/dev/null | grep -q true; do sleep 2; done' \
    || { echo "Error: Redis container did not start in time"; exit 1; }
echo "  Waiting for Redis to be healthy..."
timeout 60 bash -c 'until podman healthcheck run redis &>/dev/null; do sleep 2; done' \
    || { echo "Error: Redis did not become healthy in time"; exit 1; }
echo "  ✓ Redis ready"

echo "  Starting n8n-main..."
systemctl --user start n8n-main.service
sleep 5
echo "  ✓ N8N main started"

echo "  Starting n8n-worker@1..."
systemctl --user start "n8n-worker@1.service"
echo "  Starting n8n-worker@2..."
systemctl --user start "n8n-worker@2.service"
echo "  ✓ Workers started"

echo ""
echo "=========================================="
echo "Quadlet Setup Complete!"
echo "=========================================="
echo ""
echo "Check service status:"
echo "  systemctl --user is-active n8n-postgres n8n-redis n8n-main 'n8n-worker@1' 'n8n-worker@2'"
echo ""
echo "View logs:"
echo "  journalctl --user -u n8n-main --lines=30 --no-pager"
echo ""
echo "Run health check:"
echo "  $PODMAN_DIR/scripts/health-check.sh"
echo ""
echo "Access N8N at: http://$(grep N8N_HOST "$PROJECT_DIR/.env" | cut -d '=' -f2):5678"
echo ""
