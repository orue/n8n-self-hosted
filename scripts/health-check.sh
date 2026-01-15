#!/bin/bash

# N8N Health Check Script

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "=========================================="
echo "N8N Health Check"
echo "=========================================="
echo ""

# Check if containers are running
echo "Container Status:"
docker compose ps
echo ""

# Check container health
echo "Container Health:"
for container in n8n-postgres n8n-redis n8n-main n8n-worker-1 n8n-worker-2; do
    if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
        health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no healthcheck")
        echo "  $container: $health"
    else
        echo "  $container: NOT RUNNING"
    fi
done
echo ""

# Check disk usage
echo "Disk Usage:"
du -sh data/* 2>/dev/null || echo "  No data directories found"
echo ""

# Check logs for errors (last 50 lines)
echo "Recent Errors in Logs:"
docker compose logs --tail=50 | grep -i error || echo "  No recent errors found"
echo ""

# Check worker activity
echo "Worker Status:"
docker compose logs --tail=20 n8n-worker-1 n8n-worker-2 2>/dev/null | grep -i "job\|worker\|processing" | tail -5 || echo "  No recent worker activity"
echo ""

echo "=========================================="
