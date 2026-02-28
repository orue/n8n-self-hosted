#!/bin/bash

# N8N Backup Script (Quadlets)
# Uses podman exec directly — no compose layer needed

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PODMAN_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$PODMAN_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="n8n_backup_${TIMESTAMP}"

cd "$PROJECT_DIR"

echo "=========================================="
echo "N8N Backup (Quadlets) - $TIMESTAMP"
echo "=========================================="
echo ""

mkdir -p "$BACKUP_DIR"

# Check if required containers are running
for svc in n8n-postgres n8n-main; do
    if ! systemctl --user is-active --quiet "${svc}.service" 2>/dev/null; then
        echo "Warning: ${svc} is not running"
        read -p "Continue with backup? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        break
    fi
done

echo "Creating backup directory: $BACKUP_NAME"
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

# Backup PostgreSQL database
echo "Backing up PostgreSQL database..."
podman exec postgres pg_dump -U n8n n8n > "$BACKUP_DIR/$BACKUP_NAME/postgres_dump.sql"
echo "✓ Database backed up"

# Backup N8N data directory
echo "Backing up N8N data..."
tar -czf "$BACKUP_DIR/$BACKUP_NAME/n8n_data.tar.gz" -C data n8n
echo "✓ N8N data backed up"

# Copy .env file (excluding from tar for security)
cp .env "$BACKUP_DIR/$BACKUP_NAME/.env.backup"
echo "✓ Environment file backed up"

# Create backup info file
cat > "$BACKUP_DIR/$BACKUP_NAME/backup_info.txt" << INFO
Backup Date: $(date)
Hostname: $(hostname)
N8N Version: $(podman exec n8n-main n8n --version 2>/dev/null || echo "N/A")
Runtime: Podman Quadlets
INFO

echo ""
echo "Backup completed successfully!"
echo "Location: $BACKUP_DIR/$BACKUP_NAME"
echo ""
echo "Backup contents:"
ls -lh "$BACKUP_DIR/$BACKUP_NAME"
echo ""

# Keep only last 7 backups
BACKUP_COUNT=$(ls -1d "$BACKUP_DIR"/n8n_backup_* 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 7 ]; then
    echo "Cleaning old backups (keeping last 7)..."
    ls -1dt "$BACKUP_DIR"/n8n_backup_* | tail -n +8 | xargs rm -rf
    echo "✓ Old backups removed"
fi
