#!/bin/bash
# stop_babelfish.sh - SQL Server-style shutdown script for Babelfish DevContainer
# Purpose: Provides familiar SQL Server-like commands for Linux users
# Usage: ./stop_babelfish.sh
#
# This script gracefully stops the Babelfish DevContainer while preserving
# all data in Docker volumes and Linux backup directories.

set -e  # Exit on any error

echo "================================================================================"
echo "Babelfish for PostgreSQL - Linux Shutdown Script"
echo "================================================================================"
echo

# Check if Docker is running
if ! docker version >/dev/null 2>&1; then
    echo "ERROR: Docker is not running or not installed."
    echo "Cannot stop container - Docker is not available."
    echo
    exit 1
fi

echo "Stopping Babelfish DevContainer..."

# Change to the .devcontainer directory
cd "$(dirname "$0")/.devcontainer"

# Check if container is running
if ! docker-compose ps -q babelfish >/dev/null 2>&1; then
    echo "Container is not running or does not exist."
    show_status
    exit 0
fi

# Graceful shutdown
echo "Performing graceful shutdown of PostgreSQL..."
docker-compose exec babelfish su - postgres -c "pg_ctl -D /var/lib/babelfish/data stop -m fast" 2>/dev/null || true

echo "Stopping container..."
if ! docker-compose down; then
    echo
    echo "WARNING: Error occurred during shutdown."
    echo "Container may still be running. Check status manually:"
    echo "  docker-compose ps"
else
    echo
    echo "✓ Babelfish container stopped successfully."
fi

show_status() {
    echo
    echo "================================================================================"
    echo "Container Status:"
    echo "================================================================================"
    docker-compose ps

    echo
    echo "Data Preservation:"
    echo "  ✓ Database data preserved in Docker volume: babelfish-data"
    echo "  ✓ Backup files preserved in Docker volume: babelfish-backups"
    echo "  ✓ Linux backups preserved at: $HOME/bbf_backups"
    echo "  ✓ Container backup mount: /home/postgres/bbf_backups"
    echo
    echo "To restart Babelfish:"
    echo "  ./start_babelfish.sh"
    echo
    echo "To completely reset (WARNING - deletes all data):"
    echo "  ./reset_babelfish.sh"
    echo
    echo "================================================================================"
}

show_status
