#!/bin/bash

# N8N Health Check Script

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

detect_runtime() {
    if command -v podman &> /dev/null; then
        CONTAINER_CMD="podman"
        if podman compose version &> /dev/null 2>&1; then
            COMPOSE_CMD="podman compose"
        elif command -v podman-compose &> /dev/null; then
            COMPOSE_CMD="podman-compose"
        else
            echo "Error: Podman found but no compose provider. Install podman-compose or upgrade Podman >= 4.7"
            exit 1
        fi
        IS_PODMAN=true
    elif command -v docker &> /dev/null; then
        CONTAINER_CMD="docker"
        COMPOSE_CMD="docker compose"
        IS_PODMAN=false
    else
        echo "Error: Neither Docker nor Podman found."; exit 1
    fi
}
detect_runtime

cd "$PROJECT_DIR"

echo "=========================================="
echo "N8N Health Check"
echo "=========================================="
echo ""

# Check if containers are running
echo "Container Status:"
$COMPOSE_CMD ps
echo ""

# Check container health
echo "Container Health:"
for container in n8n-postgres n8n-redis n8n-main n8n-worker-1 n8n-worker-2; do
    if $CONTAINER_CMD ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
        health=$($CONTAINER_CMD inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no healthcheck")
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

# Check logs for errors (last 50 lines)
echo "Recent Errors in Logs:"
$COMPOSE_CMD logs --tail=50 | grep -i error || echo "  No recent errors found"
echo ""

# Check worker activity
echo "Worker Status:"
$COMPOSE_CMD logs --tail=20 n8n-worker-1 n8n-worker-2 2>/dev/null | grep -i "job\|worker\|processing" | tail -5 || echo "  No recent worker activity"
echo ""

echo "=========================================="
