#!/bin/bash
# test-volume-mount.sh - Test script to verify volume mounting works correctly

echo "=== Testing Volume Mounting Configuration ==="
echo ""

# Check if we're running inside the container
if [ -f "/.dockerenv" ]; then
    echo "✓ Running inside Docker container"
else
    echo "⚠ Not running inside Docker container - this script should be run inside the container"
fi

echo ""
echo "=== Checking Backup Directory Paths ==="

# Check Windows-mounted backup directory
if [ -d "/home/postgres/bbf_backups" ]; then
    echo "✓ Windows-mounted backup directory exists: /home/postgres/bbf_backups"
    echo "  Permissions: $(ls -ld /home/postgres/bbf_backups)"
    echo "  Contents:"
    ls -la /home/postgres/bbf_backups/ 2>/dev/null || echo "    (empty or not accessible)"
else
    echo "✗ Windows-mounted backup directory not found: /home/postgres/bbf_backups"
fi

# Check Docker volume backup directory
if [ -d "/var/lib/babelfish/bbf_backups" ]; then
    echo "✓ Docker volume backup directory exists: /var/lib/babelfish/bbf_backups"
    echo "  Permissions: $(ls -ld /var/lib/babelfish/bbf_backups)"
    echo "  Contents:"
    ls -la /var/lib/babelfish/bbf_backups/ 2>/dev/null || echo "    (empty or not accessible)"
else
    echo "✗ Docker volume backup directory not found: /var/lib/babelfish/bbf_backups"
fi

# Check home directory backup
if [ -d "$HOME/bbf_backups" ]; then
    echo "✓ Home directory backup exists: $HOME/bbf_backups"
    echo "  Permissions: $(ls -ld $HOME/bbf_backups)"
    echo "  Contents:"
    ls -la $HOME/bbf_backups/ 2>/dev/null || echo "    (empty or not accessible)"
else
    echo "✗ Home directory backup not found: $HOME/bbf_backups"
fi

echo ""
echo "=== Testing Backup Directory Discovery Logic ==="

# Test the same logic as in restore_babelfish.sh
if [[ -d "/home/postgres/bbf_backups" ]]; then
    BACKUP_BASE_DIR="/home/postgres/bbf_backups"
    echo "✓ Will use Windows-mounted directory: $BACKUP_BASE_DIR"
elif [[ -d "$HOME/bbf_backups" ]]; then
    BACKUP_BASE_DIR="$HOME/bbf_backups"
    echo "✓ Will use home directory: $BACKUP_BASE_DIR"
else
    BACKUP_BASE_DIR="/var/lib/babelfish/bbf_backups"
    echo "✓ Will use Docker volume: $BACKUP_BASE_DIR"
fi

echo ""
echo "=== Environment Variables ==="
echo "BBF_WINDOWS_BACKUPS: ${BBF_WINDOWS_BACKUPS:-not set}"
echo "BBF_DOCKER_BACKUPS: ${BBF_DOCKER_BACKUPS:-not set}"
echo "BBF_HOST_BACKUP_PATH: ${BBF_HOST_BACKUP_PATH:-not set}"

echo ""
echo "=== Test Complete ==="
echo "To test the restore script, place backup files in: $BACKUP_BASE_DIR"
echo "Example structure:"
echo "  $BACKUP_BASE_DIR/"
echo "  └── your_database_name/"
echo "      └── 2024-01-01_1200/"
echo "          ├── your_database_name.tar"
echo "          └── your_database_name.pgsql"
