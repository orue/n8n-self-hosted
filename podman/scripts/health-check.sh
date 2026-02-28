#!/bin/bash

# N8N Health Check Script (Quadlets)
# Uses systemctl --user and journalctl for service status

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PODMAN_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$PODMAN_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

cd "$PROJECT_DIR"

echo "=========================================="
echo "N8N Health Check (Quadlets)"
echo "=========================================="
echo ""

# Check systemd service status
echo "Service Status:"
for svc in n8n-postgres n8n-redis n8n-main "n8n-worker@1" "n8n-worker@2"; do
    if systemctl --user is-active --quiet "${svc}.service" 2>/dev/null; then
        echo -e "  ${svc}: ${GREEN}active${NC}"
    else
        echo -e "  ${svc}: ${RED}inactive${NC}"
    fi
done
echo ""

# Check container health via podman inspect
echo "Container Health:"
for container in postgres redis n8n-main n8n-worker-1 n8n-worker-2; do
    if podman ps --filter "name=^${container}$" --format "{{.Names}}" | grep -q "^${container}$"; then
        health=$(podman inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no healthcheck")
        echo "  $container: $health"
    else
        echo -e "  $container: ${RED}NOT RUNNING${NC}"
    fi
done
echo ""

# Check disk usage
echo "Disk Usage:"
du -sh data/* 2>/dev/null || echo "  No data directories found"
echo ""

# Check logs for recent errors
echo "Recent Errors in Logs:"
journalctl --user -u n8n-main --lines=50 --no-pager 2>/dev/null | grep -i error || echo "  No recent errors found"
echo ""

# Check worker activity
echo "Worker Status:"
for w in "n8n-worker@1" "n8n-worker@2"; do
    journalctl --user -u "${w}.service" --lines=20 --no-pager 2>/dev/null \
        | grep -i "job\|worker\|processing" | tail -3
done 2>/dev/null || echo "  No recent worker activity"
echo ""

echo "=========================================="
