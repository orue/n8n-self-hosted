#!/bin/bash

# N8N Backup Script

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="n8n_backup_${TIMESTAMP}"

cd "$PROJECT_DIR"

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

echo "=========================================="
echo "N8N Backup - $TIMESTAMP"
echo "=========================================="
echo ""

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if containers are running
if ! $COMPOSE_CMD ps | grep -q "Up\|running"; then
    echo "Warning: N8N containers are not running"
    read -p "Continue with backup? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Creating backup directory: $BACKUP_NAME"
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

# Backup PostgreSQL database
echo "Backing up PostgreSQL database..."
$COMPOSE_CMD exec -T postgres pg_dump -U n8n n8n > "$BACKUP_DIR/$BACKUP_NAME/postgres_dump.sql"
echo "✓ Database backed up"

# Backup N8N data directory
echo "Backing up N8N data..."
tar -czf "$BACKUP_DIR/$BACKUP_NAME/n8n_data.tar.gz" -C data n8n
echo "✓ N8N data backed up"

# Copy .env file (excluding it from tar for security)
cp .env "$BACKUP_DIR/$BACKUP_NAME/.env.backup"
echo "✓ Environment file backed up"

# Create backup info file
cat > "$BACKUP_DIR/$BACKUP_NAME/backup_info.txt" << INFO
Backup Date: $(date)
Hostname: $(hostname)
N8N Version: $($COMPOSE_CMD exec -T n8n-main n8n --version 2>/dev/null || echo "N/A")
INFO

echo ""
echo "Backup completed successfully!"
echo "Location: $BACKUP_DIR/$BACKUP_NAME"
echo ""
echo "Backup contents:"
ls -lh "$BACKUP_DIR/$BACKUP_NAME"
echo ""

# Optional: Keep only last 7 backups
BACKUP_COUNT=$(ls -1d "$BACKUP_DIR"/n8n_backup_* 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 7 ]; then
    echo "Cleaning old backups (keeping last 7)..."
    ls -1dt "$BACKUP_DIR"/n8n_backup_* | tail -n +8 | xargs rm -rf
    echo "✓ Old backups removed"
fi
