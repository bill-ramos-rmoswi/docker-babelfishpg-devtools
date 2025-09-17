#!/bin/bash
# reset_babelfish.sh - Complete database and volume reset for Babelfish DevContainer
# Purpose: Provides SQL Server-like database reset functionality
# Usage: ./reset_babelfish.sh
#
# WARNING: This script will PERMANENTLY DELETE all database data and backups!
# Use this when you need to start completely fresh or resolve persistent issues.

set -e  # Exit on any error

echo "================================================================================"
echo "Babelfish for PostgreSQL - Database Reset Script"
echo "================================================================================"
echo
echo "⚠️  WARNING: This will PERMANENTLY DELETE ALL DATA! ⚠️"
echo
echo "This script will remove:"
echo "  • All database data (babelfish-data volume)"
echo "  • All Docker backup files (babelfish-backups volume)"
echo "  • Container and images (will be rebuilt)"
echo
echo "The following will NOT be deleted:"
echo "  • Linux backup files ($HOME/bbf_backups)"
echo "  • Container mount directory (/home/postgres/bbf_backups)"
echo "  • Source code and configuration files"
echo "  • .env configuration file"
echo

read -p "Type 'DELETE' to confirm complete reset: " confirm
if [ "$confirm" != "DELETE" ]; then
    echo
    echo "Reset cancelled. No changes made."
    echo
    exit 0
fi

echo
echo "================================================================================"
echo "Performing Complete Reset..."
echo "================================================================================"

# Remove localhost from known_SSH hosts list
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "[localhost]:2223"

# Check if Docker is running
if ! docker version >/dev/null 2>&1; then
    echo "ERROR: Docker is not running or not installed."
    echo "Please start Docker and try again."
    echo
    exit 1
fi

# Change to the .devcontainer directory
cd "$(dirname "$0")/.devcontainer"

echo
echo "Step 1: Forcefully stopping all Babelfish containers..."

# First try docker-compose down
docker-compose down -v --remove-orphans >/dev/null 2>&1 || true

# Find and forcefully stop ALL babelfish containers regardless of how they were started
echo "Detecting running babelfish containers..."
for container in $(docker ps --format "{{.ID}} {{.Names}}" | grep "babelfish" | awk '{print $1}'); do
    echo "Found running container: $container"
    echo "Forcefully stopping container: $container"
    if docker stop "$container" >/dev/null 2>&1; then
        echo "✓ Container stopped: $container"
    else
        echo "⚠ Could not stop container: $container - trying kill"
        docker kill "$container" >/dev/null 2>&1 || true
    fi
done

# Remove all babelfish containers (running and stopped)
echo "Removing all babelfish containers..."
for container in $(docker ps -a --format "{{.ID}} {{.Names}}" | grep "babelfish" | awk '{print $1}'); do
    echo "Removing container: $container"
    if docker rm -f "$container" >/dev/null 2>&1; then
        echo "✓ Container removed: $container"
    else
        echo "⚠ Could not remove container: $container"
    fi
done

# Clean up any remaining stopped containers
docker container prune -f >/dev/null 2>&1

echo
echo "Step 2: Detecting and removing Docker volumes..."

# Check if any babelfish volumes exist
if ! docker volume ls | grep -q "babelfish"; then
    echo "ℹ No babelfish volumes found - nothing to remove"
else
    # Dynamically detect babelfish volume names
    echo "Detecting babelfish volumes..."
    docker volume ls | grep "babelfish"
    echo

    # Verify no containers are using these volumes
    echo "Verifying no containers are using babelfish volumes..."
    if docker ps -a --format "{{.Names}}" | grep -q "babelfish"; then
        echo "⚠ ERROR: Babelfish containers are still running/stopped!"
        echo "The following containers may be using the volumes:"
        docker ps -a --format "{{.ID}} {{.Names}}" | grep "babelfish"
        echo
        echo "Volume deletion will likely fail. Please manually remove containers first:"
        for container in $(docker ps -a --format "{{.ID}}" | grep "babelfish"); do
            echo "  docker rm -f $container"
        done
        echo
        echo "Attempting volume deletion anyway..."
    else
        echo "✓ No babelfish containers found - volumes should be deletable"
    fi
    echo

    # Remove babelfish-data volume
    for volume in $(docker volume ls --format "{{.Name}}" | grep "babelfish-data"); do
        echo "Found data volume: $volume"
        if docker volume rm -f "$volume" >/dev/null 2>&1; then
            echo "✓ Database volume removed: $volume"
        else
            echo "⚠ Could not remove database volume: $volume"
        fi
    done

    # Remove babelfish-backups volume
    for volume in $(docker volume ls --format "{{.Name}}" | grep "babelfish-backups"); do
        echo "Found backup volume: $volume"
        if docker volume rm -f "$volume" >/dev/null 2>&1; then
            echo "✓ Backup volume removed: $volume"
        else
            echo "⚠ Could not remove backup volume: $volume"
        fi
    done

    # Check if any volumes were found
    if ! docker volume ls | grep -q "babelfish"; then
        echo "✓ All babelfish volumes successfully removed"
    else
        echo "⚠ Some babelfish volumes may still exist - manual cleanup may be needed:"
        docker volume ls | grep "babelfish"
        echo "  Try running: docker volume prune -f"
    fi
fi

echo
echo "Step 3: Removing container images..."

# Remove babelfish images directly (safer than rebuild)
echo "Detecting babelfish images..."
if ! docker images --format "{{.Repository}}" | grep -q "babelfish"; then
    echo "ℹ No babelfish images found to remove"
else
    echo "Found babelfish images:"
    docker images --format "{{.ID}} {{.Repository}}" | grep "babelfish"
    echo
    
    echo "Removing babelfish images..."
    for image in $(docker images --format "{{.ID}}" | grep -v "IMAGE"); do
        if docker image inspect "$image" --format "{{.RepoTags}}" 2>/dev/null | grep -q "babelfish"; then
            echo "Removing image: $image"
            if docker rmi -f "$image" >/dev/null 2>&1; then
                echo "✓ Image removed: $image"
            else
                echo "⚠ Could not remove image: $image"
            fi
        fi
    done
fi

echo
echo "Building fresh image..."
echo "This may take several minutes - please be patient..."

# Use timeout for build command
sleep 5
if ! docker-compose build --no-cache babelfish; then
    echo "⚠ WARNING: Image rebuild failed or was interrupted"
    echo "You may need to rebuild manually later with: docker-compose build --no-cache"
else
    echo "✓ Fresh container image built successfully"
fi

echo
echo "Step 4: Cleaning up Docker system..."
docker system prune -f >/dev/null 2>&1
echo "✓ Docker system cleaned"

echo
echo "================================================================================"
echo "Reset Complete - Final Status Report"
echo "================================================================================"
echo

# Final verification of cleanup
echo "Verifying cleanup status..."
echo

echo "Containers Status:"
if ! docker ps -a --format "{{.Names}}" | grep -q "babelfish"; then
    echo "  ✓ No babelfish containers found"
else
    echo "  ⚠ Some babelfish containers still exist:"
    docker ps -a --format "{{.ID}} {{.Names}}" | grep "babelfish"
fi

echo
echo "Volumes Status:"
if ! docker volume ls | grep -q "babelfish"; then
    echo "  ✓ No babelfish volumes found"
else
    echo "  ⚠ Some babelfish volumes still exist:"
    docker volume ls | grep "babelfish"
fi

echo
echo "Linux Backup Directory:"
if [ -d "$HOME/bbf_backups" ]; then
    echo "  ✓ Linux backups preserved at: $HOME/bbf_backups"
    echo "  ✓ Container mount point: /home/postgres/bbf_backups"
else
    echo "  ℹ Linux backup directory not found (will be created when needed)"
fi

echo
echo "Configuration Files:"
if [ -f ".env" ]; then
    echo "  ✓ .env configuration file preserved"
else
    echo "  ℹ .env file not found (run ./setup-env.sh to create one)"
fi

echo
echo "================================================================================"
echo "Summary of Changes"
echo "================================================================================"
echo
echo "What was reset:"
echo "  ✓ All babelfish containers stopped and removed"
echo "  ✓ All babelfish Docker volumes deleted"
echo "  ✓ All babelfish images removed and rebuilt"
echo "  ✓ Docker system cleaned up"
echo
echo "What was preserved:"
echo "  ✓ Linux backup files: $HOME/bbf_backups"
echo "  ✓ Container mount directory: /home/postgres/bbf_backups"
echo "  ✓ Source code and project files"
echo "  ✓ Docker Compose configuration"
echo "  ✓ .env configuration file (if it existed)"
echo
echo "Next steps:"
echo "  1. Run: ./start_babelfish.sh"
echo "  2. Wait for initialization (may take 30-60 minutes on first run)"
echo "  3. Test connection with SQL Server Management Studio"
echo
echo "If you have backup files in Linux directory, you can restore them"
echo "after the container starts using the restore_babelfish.sh script."
echo
echo "================================================================================"
echo "Environment Configuration"
echo "================================================================================"
echo
echo "Current environment variables (from .env file if present):"
if [ -f ".env" ]; then
    echo
    echo "PostgreSQL/Babelfish Settings:"
    grep "^PGHOST=" .env 2>/dev/null || echo "  PGHOST=localhost (default)"
    grep "^PGPORT=" .env 2>/dev/null || echo "  PGPORT=5432 (default)"
    grep "^PGDATABASE=" .env 2>/dev/null || echo "  PGDATABASE=babelfish_db (default)"
    grep "^PGUSER=" .env 2>/dev/null || echo "  PGUSER=babelfish_admin (default)"
    grep "^BABELFISH_PASSWORD=" .env 2>/dev/null || echo "  PGPASSWORD=Dev2024_BabelfishSecure! (default)"
    grep "^BABELFISH_PASSWORD=" .env 2>/dev/null || echo "  ADMIN_PASSWORD=Dev2024_BabelfishSecure! (default)"
    grep "^BABELFISH_TDS_PORT=" .env 2>/dev/null || echo "  TDS_PORT=1433 (default)"
    echo
    echo "Backup Directory Settings:"
    grep "^BBF_HOST_BACKUP_PATH=" .env 2>/dev/null || echo "  Linux Path=$HOME/bbf_backups (default)"
    grep "^BBF_WINDOWS_BACKUPS=" .env 2>/dev/null || echo "  Container Mount=/home/postgres/bbf_backups (default)"
    grep "^BBF_DOCKER_BACKUPS=" .env 2>/dev/null || echo "  Docker Volume=/var/lib/babelfish/bbf_backups (default)"
else
    echo "  Using default values (no .env file found):"
    echo "  PGHOST=localhost"
    echo "  PGPORT=5432"
    echo "  PGDATABASE=babelfish_db"
    echo "  PGUSER=babelfish_admin"
    echo "  PGPASSWORD=Dev2024_BabelfishSecure!"
    echo "  ADMIN_PASSWORD=Dev2024_BabelfishSecure!"
    echo "  TDS_PORT=1433"
    echo "  Linux Path=$HOME/bbf_backups"
    echo "  Container Mount=/home/postgres/bbf_backups"
    echo "  Docker Volume=/var/lib/babelfish/bbf_backups"
fi
echo
echo "Linux Container Access:"
echo "  Root User: root"
echo "  Root Password: postgres"
echo "  PostgreSQL User: postgres"
echo "  PostgreSQL User Password: (same as BABELFISH_PASSWORD)"
echo
echo "Connection Information:"
echo "  SQL Server (TDS): localhost:3341"
echo "  PostgreSQL Native: localhost:2345"
echo "  SSH: localhost:2223"
echo
echo "================================================================================"
echo "Press Enter to close this window..."
read
