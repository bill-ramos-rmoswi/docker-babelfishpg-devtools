#!/bin/bash
# start_babelfish.sh - SQL Server-style startup script for Babelfish DevContainer
# Purpose: Provides familiar SQL Server-like commands for Linux users
# Usage: ./start_babelfish.sh [options]
#
# This script starts the Babelfish DevContainer and ensures Linux backup
# directories are properly set up and accessible.

set -e  # Exit on any error

echo "================================================================================"
echo "Babelfish for PostgreSQL - Linux Startup Script"
echo "================================================================================"
echo

# Check if Docker is running
if ! docker version >/dev/null 2>&1; then
    echo "ERROR: Docker is not running or not installed."
    echo "Please start Docker and try again."
    echo
    exit 1
fi

# Create Linux backup directory if it doesn't exist
BACKUP_DIR="$HOME/bbf_backups"
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Creating Linux backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR" 2>/dev/null || {
        echo "WARNING: Could not create backup directory at $BACKUP_DIR"
        echo "You may need to check permissions."
    }
    echo "✓ Created backup directory: $BACKUP_DIR"
else
    echo "✓ Backup directory exists: $BACKUP_DIR"
fi

echo
echo "Starting Babelfish DevContainer..."
echo "Please wait while the container initializes..."

# Change to the .devcontainer directory
cd "$(dirname "$0")/.devcontainer"

# Check if .env file exists - required for credentials
if [ ! -f ".env" ]; then
    echo
    echo "⚠️  CONFIGURATION REQUIRED: .env file not found"
    echo
    echo "The .env file contains database credentials and is required to start Babelfish."
    echo "Please create .env file in the .devcontainer directory."
    echo
    echo "Option 1 - Copy from template:"
    echo "  cp ../env.template .env"
    echo "  Edit .env with your preferred credentials"
    echo
    echo "Option 2 - Create minimal .env file:"
    echo "  echo 'PGUSER=babelfish_admin' > .env"
    echo "  echo 'BABELFISH_PASSWORD=YourSecurePassword123!' >> .env"
    echo "  echo 'PGDATABASE=babelfish_db' >> .env"
    echo "  echo 'PGHOST=localhost' >> .env"
    echo "  echo 'PGPORT=5432' >> .env"
    echo
    echo "Note: ADMIN_USERNAME and ADMIN_PASSWORD will automatically use PGUSER and BABELFISH_PASSWORD"
    echo
    echo "⚠️  SECURITY NOTE: Never commit .env files to version control!"
    echo
    read -p "Press Enter to continue..."
    exit 1
fi

echo "✓ Environment configuration (.env) found"
echo

# Source the .env file to load environment variables
set -o allexport
source .env
set +o allexport

# Start the container using docker-compose
if ! docker-compose up -d; then
    echo
    echo "ERROR: Failed to start Babelfish container."
    echo "Please check Docker logs for details:"
    echo "  docker-compose logs babelfish"
    echo
    exit 1
fi

echo
echo "Waiting for Babelfish to be ready..."

# Wait for container to be healthy (max 60 seconds)
timeout=60
count=0

while [ $count -lt $timeout ]; do
    if docker-compose exec -T babelfish pg_isready -h localhost -p 5432 -U "$PGUSER" >/dev/null 2>&1; then
        break
    fi
    
    count=$((count + 1))
    if [ $count -ge $timeout ]; then
        echo
        echo "ERROR: Babelfish did not become ready within $timeout seconds."
        echo "Please check the container status:"
        echo "  docker-compose logs babelfish"
        break
    fi
    
    echo "Waiting... ($count/$timeout)"
    sleep 1
done

echo
echo "================================================================================"
echo "✓ Babelfish for PostgreSQL is now running!"
echo "================================================================================"

echo
echo "Connection Information:"
echo "  SQL Server (TDS) Port: localhost:3341"
echo "  PostgreSQL Port:        localhost:2345"
echo "  SSH Port:              localhost:2223"
echo
echo "================================================================================"
echo "Environment Configuration"
echo "================================================================================"
echo
echo "Current environment variables:"
echo
echo "PostgreSQL/Babelfish Settings:"
echo "  PGHOST=$PGHOST"
echo "  PGPORT=$PGPORT"
echo "  PGDATABASE=$PGDATABASE"
echo "  PGUSER=$PGUSER"
echo "  PGPASSWORD=$PGPASSWORD"
echo "  ADMIN_USERNAME=$ADMIN_USERNAME"
echo "  ADMIN_PASSWORD=$ADMIN_PASSWORD"
echo "  TDS_PORT=$BABELFISH_TDS_PORT"
echo
echo "Backup Directory Settings:"
echo "  Windows Path=$BBF_HOST_BACKUP_PATH"
echo "  Container Mount=$BBF_WINDOWS_BACKUPS"
echo "  Docker Volume=$BBF_DOCKER_BACKUPS"
echo
echo "Linux Container Access:"
echo "  Root User: root"
echo "  Root Password: postgres"
echo "  PostgreSQL User: postgres"
echo "  PostgreSQL User Password: (same as BABELFISH_PASSWORD)"
echo
echo "================================================================================"
echo
echo "Backup Locations:"
echo "  Linux: $BACKUP_DIR"
echo "  Container: /home/postgres/bbf_backups (mounted from Linux)"
echo "  Docker Volume: /var/lib/babelfish/bbf_backups (persistent)"
echo
echo "Management Commands:"
echo "  ./stop_babelfish.sh      - Stop the container"
echo "  ./reset_babelfish.sh     - Reset database and volumes"
echo
echo "Container Status:"
docker-compose ps

echo
echo "SQL Server Management Studio Connection String:"
echo "Data Source=localhost,3341;Initial Catalog=$PGDATABASE;User ID=$PGUSER;Password=$PGPASSWORD;TrustServerCertificate=true;"
echo
echo "================================================================================"
echo "Press Enter to close this window..."
read
