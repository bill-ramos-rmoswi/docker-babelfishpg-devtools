#!/bin/bash
# reset_database.sh - Reset Babelfish database while preserving container
# Purpose: Reinitialize database cluster without rebuilding entire container
# Usage: ./reset_database.sh [--force] [--keep-backups]
#
# This script provides a middle ground between full container reset and normal
# operation - it reinitializes the database cluster while keeping the container
# and optionally preserving backup files.

set -e

# Source .env file if it exists for credential management
if [ -f "/workspace/.devcontainer/.env" ]; then
    set -o allexport
    source /workspace/.devcontainer/.env
    set +o allexport
elif [ -f "/workspace/.env" ]; then
    set -o allexport
    source /workspace/.env
    set +o allexport
elif [ -f "$(dirname "$0")/.devcontainer/.env" ]; then
    set -o allexport
    source "$(dirname "$0")/.devcontainer/.env"
    set +o allexport
elif [ -f "$(dirname "$0")/.env" ]; then
    set -o allexport
    source "$(dirname "$0")/.env"
    set +o allexport
fi

# Set default credentials from environment or fallbacks
RESET_ADMIN_USER=${ADMIN_USERNAME:-babelfish_admin}
RESET_ADMIN_PASSWORD=${ADMIN_PASSWORD:-Dev2024_BabelfishSecure!}
RESET_ADMIN_DATABASE=${ADMIN_DATABASE:-babelfish_db}
RESET_MIGRATION_MODE=${MIGRATION_MODE:-multi-db}

show_help() {
    cat << EOF
reset_database.sh - Reset Babelfish database cluster

USAGE:
    $(basename "$0") [OPTIONS]

DESCRIPTION:
    Reinitializes the Babelfish database cluster while keeping the container
    running. This is useful when you need a fresh database but don't want
    to rebuild the entire container.

    WARNING: This will DELETE all database data and configuration!

OPTIONS:
    -h, --help         Show this help message and exit
    -f, --force        Skip confirmation prompt
    -k, --keep-backups Keep existing backup files
    -v, --verbose      Show detailed output

WHAT GETS RESET:
    ✗ All database data (/var/lib/babelfish/data)
    ✗ Database configuration files
    ✗ All user databases and tables
    ✗ All users and permissions (except babelfish_admin)

WHAT GETS PRESERVED:
    ✓ Container and installed software
    ✓ Backup files (if --keep-backups specified)
    ✓ Source code and scripts
    ✓ Docker volumes (structure remains)

EXAMPLES:
    $(basename "$0")                    # Interactive reset
    $(basename "$0") --force            # Non-interactive reset
    $(basename "$0") --keep-backups     # Reset but preserve backups

EXIT CODES:
    0    Success  
    1    General error
    2    User cancelled operation
    3    Database not running

EOF
}

# Default options
FORCE=false
KEEP_BACKUPS=false
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -k|--keep-backups)
            KEEP_BACKUPS=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            show_help
            exit 1
            ;;
        *)
            echo "Error: Unexpected argument $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# Logging function
log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo "  $1"
    fi
}

echo "=================================================================================="
echo "Babelfish Database Cluster Reset"
echo "=================================================================================="
echo

# Check if running in container
if [[ ! -f /.dockerenv ]]; then
    echo "ERROR: This script must run inside the Docker container."
    echo "Run this script using:"
    echo "  docker-compose exec babelfish ./reset_database.sh"
    exit 1
fi

# Check if we have required privileges
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Root privileges required for database reset."
    echo "Run with: docker-compose exec --user root babelfish ./reset_database.sh"
    exit 2
fi

# Source environment variables
if [[ -f /etc/profile.d/pg_env.sh ]]; then
    source /etc/profile.d/pg_env.sh
fi

# Set required variables
BABELFISH_HOME=${BABELFISH_HOME:-/opt/babelfish}
BABELFISH_DATA=${BABELFISH_DATA:-/var/lib/babelfish/data}
BABELFISH_BIN=${BABELFISH_BIN:-${BABELFISH_HOME}/bin}

echo "⚠️  WARNING: Database Reset Operation ⚠️"
echo
echo "This will PERMANENTLY DELETE:"
echo "  • All database data and configuration"
echo "  • All user databases and tables"  
echo "  • All database users (except babelfish_admin)"
echo "  • Database logs and transaction history"
echo
if [[ "$KEEP_BACKUPS" == true ]]; then
    echo "Backup files will be PRESERVED."
else
    echo "Backup files will be DELETED."
fi
echo
echo "The container will remain running with a fresh database cluster."

if [[ "$FORCE" != true ]]; then
    echo
    read -p "Type 'RESET' to confirm database reset: " confirm
    if [[ "$confirm" != "RESET" ]]; then
        echo "Reset cancelled. No changes made."
        exit 2
    fi
fi

echo
echo "=================================================================================="
echo "Performing Database Reset..."
echo "=================================================================================="

# Step 1: Stop PostgreSQL if running
echo
echo "Step 1: Stopping PostgreSQL..."
if pgrep -f "postgres.*-D.*${BABELFISH_DATA}" > /dev/null; then
    log_verbose "PostgreSQL is running, stopping..."
    su - postgres -c "${BABELFISH_BIN}/pg_ctl -D ${BABELFISH_DATA} stop -m fast" || true
    sleep 2
    echo "✓ PostgreSQL stopped"
else
    echo "✓ PostgreSQL not running"
fi

# Step 2: Remove database data directory
echo
echo "Step 2: Removing database data..."
if [[ -d "$BABELFISH_DATA" ]]; then
    log_verbose "Removing: $BABELFISH_DATA"
    rm -rf "$BABELFISH_DATA"
    echo "✓ Database data removed"
else
    echo "✓ Database data directory not found (already clean)"
fi

# Step 3: Remove backup files (unless keeping them)
if [[ "$KEEP_BACKUPS" != true ]]; then
    echo
    echo "Step 3: Removing backup files..."
    
    if [[ -d "/var/lib/babelfish/bbf_backups" ]]; then
        log_verbose "Cleaning Docker backups: /var/lib/babelfish/bbf_backups"
        rm -rf /var/lib/babelfish/bbf_backups/*
        echo "✓ Docker backup files removed"
    fi
    
    if [[ -d "/var/lib/babelfish/windows_backups" ]]; then
        log_verbose "Cleaning Windows backups: /var/lib/babelfish/windows_backups"
        rm -rf /var/lib/babelfish/windows_backups/* 2>/dev/null || true
        echo "✓ Windows backup files removed"
    fi
else
    echo
    echo "Step 3: Preserving backup files (--keep-backups specified)"
fi

# Step 4: Recreate directory structure
echo
echo "Step 4: Recreating directory structure..."
mkdir -p "$BABELFISH_DATA"
mkdir -p "/var/lib/babelfish/bbf_backups"
mkdir -p "/var/lib/babelfish/windows_backups" 2>/dev/null || true

log_verbose "Setting ownership and permissions"
chown -R postgres:postgres /var/lib/babelfish/
chmod 700 "$BABELFISH_DATA"

echo "✓ Directory structure recreated"

# Step 5: Initialize fresh database cluster
echo
echo "Step 5: Initializing fresh database cluster..."
log_verbose "Running initdb"
su - postgres -c "${BABELFISH_BIN}/initdb -D ${BABELFISH_DATA} -E 'UTF8'"

# Step 6: Configure PostgreSQL
echo
echo "Step 6: Configuring PostgreSQL..."

# Add HBA configuration
log_verbose "Configuring authentication"
cat >> ${BABELFISH_DATA}/pg_hba.conf << 'EOF'
# Allow all connections
hostssl	all		all		0.0.0.0/0		md5
hostssl	all		all		::0/0				md5
EOF

# Add PostgreSQL configuration
log_verbose "Configuring PostgreSQL settings"
cat >> ${BABELFISH_DATA}/postgresql.conf << 'EOF'
#------------------------------------------------------------------------------
# BABELFISH RELATED OPTIONS
#------------------------------------------------------------------------------
listen_addresses = '*'
allow_system_table_mods = on
shared_preload_libraries = 'babelfishpg_tds'
babelfishpg_tds.listen_addresses = '*'
ssl = on

#------------------------------------------------------------------------------
# LOGGING OPTIONS
#------------------------------------------------------------------------------
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_truncate_on_rotation = on
log_min_messages = info
log_min_error_statement = error
log_connections = on
log_disconnections = on
log_duration = off
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_statement = 'all'
log_timezone = 'UTC'
EOF

# Create log directory
mkdir -p ${BABELFISH_DATA}/log
chown postgres:postgres ${BABELFISH_DATA}/log
chmod 700 ${BABELFISH_DATA}/log

echo "✓ PostgreSQL configured"

# Step 7: Generate SSL certificates
echo
echo "Step 7: Generating SSL certificates..."
cd ${BABELFISH_DATA}
log_verbose "Creating self-signed certificate"
openssl req -new -x509 -days 365 -nodes -text -out server.crt \
    -keyout server.key -subj "/CN=localhost" >/dev/null 2>&1
chmod og-rwx server.key
chown postgres:postgres server.key server.crt
echo "✓ SSL certificates generated"

# Step 8: Start PostgreSQL and initialize Babelfish
echo
echo "Step 8: Starting PostgreSQL and initializing Babelfish..."

log_verbose "Starting PostgreSQL"
su - postgres -c "${BABELFISH_BIN}/pg_ctl -D ${BABELFISH_DATA} start"

# Wait for PostgreSQL to be ready
log_verbose "Waiting for PostgreSQL to be ready..."
for i in $(seq 1 30); do
    if su - postgres -c "${BABELFISH_BIN}/pg_isready -U postgres" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

# Initialize Babelfish
log_verbose "Creating ${RESET_ADMIN_USER} user and initializing Babelfish"
su - postgres -c "${BABELFISH_BIN}/psql -U postgres -d postgres" << EOF
CREATE USER ${RESET_ADMIN_USER} WITH SUPERUSER CREATEDB CREATEROLE PASSWORD '${RESET_ADMIN_PASSWORD}' INHERIT;
DROP DATABASE IF EXISTS ${RESET_ADMIN_DATABASE};
CREATE DATABASE ${RESET_ADMIN_DATABASE} OWNER ${RESET_ADMIN_USER};
\c ${RESET_ADMIN_DATABASE}
CREATE EXTENSION IF NOT EXISTS "babelfishpg_tds" CASCADE;
GRANT ALL ON SCHEMA sys to ${RESET_ADMIN_USER};
ALTER USER ${RESET_ADMIN_USER} CREATEDB;
ALTER SYSTEM SET babelfishpg_tsql.database_name = '${RESET_ADMIN_DATABASE}';
SELECT pg_reload_conf();
ALTER DATABASE ${RESET_ADMIN_DATABASE} SET babelfishpg_tsql.migration_mode = '${RESET_MIGRATION_MODE}';
SELECT pg_reload_conf();
CALL SYS.INITIALIZE_BABELFISH('${RESET_ADMIN_USER}');
EOF

echo "✓ Babelfish initialized"

echo
echo "=================================================================================="
echo "Database Reset Complete!"
echo "=================================================================================="
echo
echo "Fresh database cluster initialized with:"
echo "  • Username: ${RESET_ADMIN_USER}"
echo "  • Password: ${RESET_ADMIN_PASSWORD}"
echo "  • Database: ${RESET_ADMIN_DATABASE}"
echo "  • Migration mode: ${RESET_MIGRATION_MODE}"
echo
echo "Connection Information:"
echo "  • SQL Server (TDS): localhost:1433"
echo "  • PostgreSQL: localhost:5432"
echo
echo "Next Steps:"
echo "  1. Test connection from your SQL client"
echo "  2. If you have backup files, restore them using restore_babelfish.sh"
echo "  3. Create your databases and import data as needed"
echo
echo "=================================================================================="