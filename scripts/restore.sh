#!/bin/bash
# Restore a database backup into the running PostgreSQL container

if [ -z "$1" ]; then
    echo "Usage: $0 <backup_file.sql>"
    echo ""
    echo "Available backups:"
    ls -lh "$(dirname "$0")/../backups/"
    exit 1
fi

BACKUP_FILE="$1"
if [ ! -f "$BACKUP_FILE" ]; then
    echo "File not found: $BACKUP_FILE"
    exit 1
fi

echo "Restoring from $BACKUP_FILE ..."
docker exec -i library_db psql -U librarian -d library < "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "Restore completed successfully."
else
    echo "Restore FAILED."
    exit 1
fi
