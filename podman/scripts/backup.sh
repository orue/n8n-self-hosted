#!/bin/bash

# N8N Backup Script (Podman Quadlets)
# Creates a timestamped backup of PostgreSQL, N8N data, and config.
#
# Usage:
#   ./podman/scripts/backup.sh
#   ./podman/scripts/backup.sh --retention 14   (keep last N backups, default 7)
#
# Restore:
#   pg_restore -h 127.0.0.1 -p 5432 -U n8n -d n8n backups/<name>/postgres.dump
#   OR via podman: podman exec -i postgres pg_restore -U n8n -d n8n < backups/<name>/postgres.dump

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PODMAN_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$PODMAN_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="n8n_backup_${TIMESTAMP}"
RETENTION=7

# Parse optional --retention flag
while [[ $# -gt 0 ]]; do
    case "$1" in
        --retention) RETENTION="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

cd "$PROJECT_DIR"

echo "=========================================="
echo "N8N Backup — $(date)"
echo "=========================================="
echo ""

mkdir -p "$BACKUP_DIR"

# Check that required containers are running
for svc in n8n-postgres n8n-main; do
    if ! systemctl --user is-active --quiet "${svc}.service" 2>/dev/null; then
        echo "Warning: ${svc} is not active"
        read -p "Continue anyway? [y/N] " -n 1 -r; echo
        [[ $REPLY =~ ^[Yy]$ ]] || exit 1
        break
    fi
done

BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
echo "Destination: $BACKUP_PATH"
mkdir -p "$BACKUP_PATH"

# PostgreSQL — custom format (compressed, supports selective restore)
echo "Backing up PostgreSQL..."
podman exec postgres pg_dump -U n8n --format=custom n8n > "$BACKUP_PATH/postgres.dump"
echo "  ✓ postgres.dump ($(du -sh "$BACKUP_PATH/postgres.dump" | cut -f1))"

# N8N data directory (custom nodes, encryption key cache, etc.)
echo "Backing up N8N data directory..."
tar -czf "$BACKUP_PATH/n8n_data.tar.gz" -C data n8n
echo "  ✓ n8n_data.tar.gz ($(du -sh "$BACKUP_PATH/n8n_data.tar.gz" | cut -f1))"

# .env (config — keep permissions tight)
cp .env "$BACKUP_PATH/.env.backup"
chmod 600 "$BACKUP_PATH/.env.backup"
echo "  ✓ .env.backup"

# Metadata
N8N_VERSION=$(podman exec n8n-main n8n --version 2>/dev/null || echo "N/A")
cat > "$BACKUP_PATH/backup_info.txt" << INFO
Backup Date:  $(date)
Hostname:     $(hostname)
N8N Version:  ${N8N_VERSION}
Runtime:      Podman Quadlets

Restore PostgreSQL:
  podman exec -i postgres pg_restore -U n8n -d n8n --clean < $BACKUP_PATH/postgres.dump

Restore N8N data:
  tar -xzf $BACKUP_PATH/n8n_data.tar.gz -C data
INFO
echo "  ✓ backup_info.txt"

echo ""
echo "Backup complete: $BACKUP_PATH"
du -sh "$BACKUP_PATH"
echo ""

# Rotate old backups
BACKUP_COUNT=$(ls -1d "$BACKUP_DIR"/n8n_backup_* 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt "$RETENTION" ]; then
    echo "Rotating backups (keeping last ${RETENTION})..."
    ls -1dt "$BACKUP_DIR"/n8n_backup_* | tail -n "+$((RETENTION + 1))" | xargs rm -rf
    echo "  ✓ Kept last ${RETENTION} backups"
fi
