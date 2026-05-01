#!/bin/bash
# Database backup script – dumps PostgreSQL data from the running container

BACKUP_DIR="$(dirname "$0")/../backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/library_backup_$DATE.sql"

mkdir -p "$BACKUP_DIR"

echo "Starting backup → $BACKUP_FILE"
docker exec library_db pg_dump -U librarian library > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "Backup successful  (size: $SIZE)"
    echo "File: $BACKUP_FILE"
else
    echo "Backup FAILED"
    rm -f "$BACKUP_FILE"
    exit 1
fi
