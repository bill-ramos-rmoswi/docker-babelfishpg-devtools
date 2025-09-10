#!/bin/bash
# backup_babelfish.sh - Backup Babelfish T-SQL Database
# Make script executable (if needed)
# chmod +x backup_babelfish.sh
#
# PURPOSE:
# This script automates the backup of individual Babelfish T-SQL databases using
# bbf_dumpall and bbf_dump utilities. It organizes backups in a structured directory
# format for easy management and restoration.
#
# REQUIREMENTS:
# - Amazon Linux 2023 (AL2023) EC2 instance
# - Babelfish dump utilities installed via: sudo yum install -y BabelfishDump
# - PostgreSQL client tools installed: sudo yum install -y postgresql
# - SSH access to the EC2 instance where this script will run
#
# LIMITATIONS:
# - Only TAR format is used for database backups as it works best for large databases
# - See full limitations at:
#   https://github.com/babelfish-for-postgresql/babelfish-for-postgresql/wiki/Babelfish-dump-and-restore#limitations-and-requirements

show_help() {
    cat << EOF
backup_babelfish.sh - Backup Babelfish T-SQL Database

USAGE:
    $(basename "$0") [OPTIONS] BBF_DATABASE_NAME

DESCRIPTION:
    Creates a backup of a Babelfish T-SQL database using bbf_dumpall and bbf_dump.
    Files are organized in a structured directory format under \$HOME/bbf_backups/.

ARGUMENTS:
    BBF_DATABASE_NAME   Name of the Babelfish T-SQL database to backup

OPTIONS:
    -h, --help          Show this help message and exit
    -t, --time          Show timing information for backup operations

DIRECTORY STRUCTURE:
    \$HOME/bbf_backups/
    ├── database_name/
    │   └── YYYY-MM-DD_HHMM/
    │       ├── database_name.tar   (bbf_dump output)
    │       └── database_name.pgsql (bbf_dumpall output)

ENVIRONMENT VARIABLES:
    PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD
    These can be set in ~/db_config.sh which will be automatically sourced

EXAMPLES:
    $(basename "$0") northwind
    $(basename "$0") -h

EXIT CODES:
    0    Success
    1    General error
    2    Missing required arguments
    3    Database connection failed
    4    Database does not exist

EOF
}

# Parse command line arguments
USE_TIME=false
BBF_DATABASE_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--time)
            USE_TIME=true
            shift
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            show_help
            exit 2
            ;;
        *)
            if [[ -z "$BBF_DATABASE_NAME" ]]; then
                BBF_DATABASE_NAME="$1"
            else
                echo "Error: Multiple database names specified" >&2
                show_help
                exit 2
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$BBF_DATABASE_NAME" ]]; then
    echo "Error: BBF_DATABASE_NAME is required" >&2
    show_help
    exit 2
fi

# Source environment variables
if [[ -f ~/db_config.sh ]]; then
    source ~/db_config.sh
else
    echo "Warning: ~/db_config.sh not found. Ensure environment variables are set."
fi

# Validate required environment variables
if [[ -z "$PGHOST" || -z "$PGPORT" || -z "$PGDATABASE" || -z "$PGUSER" ]]; then
    echo "Error: Required environment variables not set (PGHOST, PGPORT, PGDATABASE, PGUSER)" >&2
    show_help
    exit 2
fi

# Configuration
BACKUP_DATE=$(date +%Y-%m-%d_%H%M)
BACKUP_BASE_DIR="$HOME/bbf_backups"
BACKUP_DIR="${BACKUP_BASE_DIR}/${BBF_DATABASE_NAME}/${BACKUP_DATE}"
ROLES_FILE="${BACKUP_DIR}/${BBF_DATABASE_NAME}.pgsql"
DB_FILE="${BACKUP_DIR}/${BBF_DATABASE_NAME}.tar"

# Time command setup
TIME_CMD=""
if [[ "$USE_TIME" == true ]]; then
    TIME_CMD="time"
fi

echo "Starting backup of Babelfish database: $BBF_DATABASE_NAME"
echo "Backup directory: $BACKUP_DIR"
echo "Target host: $PGHOST:$PGPORT"

# Test database connectivity
echo "Testing database connection..."
if ! psql --host="$PGHOST" --port="$PGPORT" --dbname="$PGDATABASE" --username="$PGUSER" -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✗ Cannot connect to database server" >&2
    echo ""
    show_help
    exit 3
fi

# Check if BBF database exists
echo "Checking if database '$BBF_DATABASE_NAME' exists..."
DB_EXISTS=$(psql --host="$PGHOST" --port="$PGPORT" --dbname="$PGDATABASE" --username="$PGUSER" -t -c "SELECT name FROM sys.databases WHERE name = '$BBF_DATABASE_NAME';" 2>/dev/null | tr -d ' ')

if [[ -z "$DB_EXISTS" ]]; then
    echo "✗ Database '$BBF_DATABASE_NAME' does not exist" >&2
    echo ""
    echo "Available databases:"
    psql --host="$PGHOST" --port="$PGPORT" --dbname="$PGDATABASE" --username="$PGUSER" -c "SELECT name AS \"Available databases\" FROM sys.databases WHERE database_id > 4;" 2>/dev/null
    exit 4
fi

echo "✓ Database '$BBF_DATABASE_NAME' found"

# Create backup directory
mkdir -p "$BACKUP_DIR"
if [[ $? -ne 0 ]]; then
    echo "✗ Failed to create backup directory: $BACKUP_DIR" >&2
    exit 1
fi

# Step 1: Backup T-SQL roles with bbf_dumpall
echo ""
echo "Step 1: Backing up T-SQL roles and schema..."
echo "Output file: $ROLES_FILE"

$TIME_CMD bbf_dumpall --database "$PGDATABASE" \
                      --host="$PGHOST" \
                      --port="$PGPORT" \
                      --username "$PGUSER" \
                      --bbf-database-name="$BBF_DATABASE_NAME" \
                      --roles-only \
                      --quote-all-identifiers \
                      --verbose \
                      --no-role-passwords \
                      -f "$ROLES_FILE"

if [[ $? -eq 0 ]]; then
    echo "✓ Roles backup completed: $ROLES_FILE"
    echo "  File size: $(du -h "$ROLES_FILE" | cut -f1)"
else
    echo "✗ Roles backup failed" >&2
    exit 1
fi

# Step 2: Backup database contents with bbf_dump
echo ""
echo "Step 2: Backing up database contents..."
echo "Output file: $DB_FILE"

$TIME_CMD bbf_dump --dbname="$PGDATABASE" \
                   --host="$PGHOST" \
                   --port="$PGPORT" \
                   --username "$PGUSER" \
                   --bbf-database-name="$BBF_DATABASE_NAME" \
                   --quote-all-identifiers \
                   --verbose \
                   --file="$DB_FILE" \
                   --format=tar

if [[ $? -eq 0 ]]; then
    echo "✓ Database backup completed: $DB_FILE"
    echo "  File size: $(du -h "$DB_FILE" | cut -f1)"
else
    echo "✗ Database backup failed" >&2
    exit 1
fi

# Summary
echo ""
echo "=== Backup Summary ==="
echo "Database: $BBF_DATABASE_NAME"
echo "Backup directory: $BACKUP_DIR"
echo "Files created:"
echo "  - Roles/Schema: $ROLES_FILE ($(du -h "$ROLES_FILE" | cut -f1))"
echo "  - Data/Objects: $DB_FILE ($(du -h "$DB_FILE" | cut -f1))"
echo "Total backup size: $(du -sh "$BACKUP_DIR" | cut -f1)"
echo ""
echo "✓ Backup completed successfully"