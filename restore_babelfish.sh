#!/bin/bash
# restore_babelfish.sh - Restore Babelfish T-SQL Database
# Make script executable (if needed)
# chmod +x restore_babelfish.sh
#
# PURPOSE:
# This script restores Babelfish T-SQL databases that were backed up using
# the companion backup_babelfish.sh script. It handles proper sequencing of
# restore steps to ensure database integrity.
#
# REQUIREMENTS:
# - Amazon Linux 2023 (AL2023) EC2 instance
# - PostgreSQL client tools installed: sudo yum install -y postgresql
# - SSH access to the EC2 instance where this script will run
#
# LIMITATIONS:
# - A Babelfish logical database must be restored with the same name as the original
# - See full limitations at:
#   https://github.com/babelfish-for-postgresql/babelfish-for-postgresql/wiki/Babelfish-dump-and-restore#limitations-and-requirements
#
# NOTE: With recent Babelfish versions, you can work around the database name limitation
# by first renaming any conflicting target database using T-SQL:
#   ALTER DATABASE existing_db RENAME TO existing_db_old
#   (This option is not automated by this script)

show_help() {
    cat << EOF
restore_babelfish.sh - Restore Babelfish T-SQL Database

USAGE:
    $(basename "$0") [OPTIONS] BBF_DATABASE_NAME

DESCRIPTION:
    Restores a Babelfish T-SQL database from backup files. If -r and -d options
    are not specified, the script will automatically find the latest backup
    for the specified database name.

    The script checks for database name conflicts before restoring. If a database
    with the same name exists on the target server, the restore will fail.
    In newer Babelfish versions (post 2023), you can manually rename the conflicting
    database first using T-SQL: ALTER DATABASE existing_db RENAME TO existing_db_old

    After the restore, be sure to reset the table identity values.

ARGUMENTS:
    BBF_DATABASE_NAME   Name of the Babelfish T-SQL database to restore

OPTIONS:
    -h, --help              Show this help message and exit
    -r, --roles-file FILE   Path to roles pgsql file (optional)
    -d, --database-file FILE Path to database tar file (optional)
    -t, --time              Show timing information for restore operations
    --target-host HOST      Target host (uses TARGET_PGHOST env var if not specified)

DIRECTORY STRUCTURE (for auto-discovery):
    \$HOME/bbf_backups/
    ├── database_name/
    │   └── YYYY-MM-DD_HHMM/
    │       ├── database_name.tar   (bbf_dump output)
    │       └── database_name.pgsql (bbf_dumpall output)

ENVIRONMENT VARIABLES:
    PGPORT, PGDATABASE, PGUSER, PGPASSWORD, TARGET_PGHOST
    These can be set in ~/db_config.sh which will be automatically sourced

EXAMPLES:
    $(basename "$0") northwind
    $(basename "$0") --time --target-host=target.cluster.amazonaws.com northwind
    $(basename "$0") -r backup.pgsql -d backup.tar northwind

EXIT CODES:
    0    Success
    1    General error
    2    Missing required arguments
    3    Database connection failed
    4    Database already exists
    5    Backup files not found
    6    Version mismatch error

EOF
}

# Parse command line arguments
USE_TIME=false
BBF_DATABASE_NAME=""
ROLES_FILE=""
DB_FILE=""
RESTORE_HOST=""

# Add Babelfish bin directory to PATH
export PATH=/opt/babelfish/bin:$PATH

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -r|--roles-file)
            ROLES_FILE="$2"
            shift 2
            ;;
        -d|--database-file)
            DB_FILE="$2"
            shift 2
            ;;
        -t|--time)
            USE_TIME=true
            shift
            ;;
        --target-host)
            RESTORE_HOST="$2"
            shift 2
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

# Set target host
RESTORE_HOST=${RESTORE_HOST:-$TARGET_PGHOST}
if [[ -z "$RESTORE_HOST" ]]; then
    echo "Error: Target host not specified. Use --target-host option or set TARGET_PGHOST environment variable" >&2
    show_help
    exit 2
fi

# Validate required environment variables
if [[ -z "$PGPORT" || -z "$PGDATABASE" || -z "$PGUSER" ]]; then
    echo "Error: Required environment variables not set (PGPORT, PGDATABASE, PGUSER)" >&2
    show_help
    exit 2
fi

# Auto-discover backup files if not specified
if [[ -z "$ROLES_FILE" || -z "$DB_FILE" ]]; then
    BACKUP_BASE_DIR="$HOME/bbf_backups"
    DB_BACKUP_DIR="$BACKUP_BASE_DIR/$BBF_DATABASE_NAME"
    
    if [[ ! -d "$DB_BACKUP_DIR" ]]; then
        echo "Error: No backup directory found for database '$BBF_DATABASE_NAME'" >&2
        echo "Expected: $DB_BACKUP_DIR" >&2
        exit 5
    fi
    
    # Find latest backup (newest date_time folder)
    LATEST_BACKUP=$(find "$DB_BACKUP_DIR" -maxdepth 1 -type d -name "????-??-??_????" | sort -r | head -n1)
    
    if [[ -z "$LATEST_BACKUP" ]]; then
        echo "Error: No backup folders found in $DB_BACKUP_DIR" >&2
        exit 5
    fi
    
    ROLES_FILE="$LATEST_BACKUP/${BBF_DATABASE_NAME}.pgsql"
    DB_FILE="$LATEST_BACKUP/${BBF_DATABASE_NAME}.tar"
    
    echo "Auto-discovered backup files:"
    echo "  Backup date: $(basename "$LATEST_BACKUP")"
    echo "  Roles file: $ROLES_FILE"
    echo "  Database file: $DB_FILE"
fi

# Verify files exist
if [[ ! -f "$ROLES_FILE" ]]; then
    echo "Error: Roles file not found: $ROLES_FILE" >&2
    exit 5
fi

if [[ ! -f "$DB_FILE" ]]; then
    echo "Error: Database file not found: $DB_FILE" >&2
    exit 5
fi

# Time command setup
TIME_CMD=""
if [[ "$USE_TIME" == true ]]; then
    TIME_CMD="time"
fi

echo "Starting restore of Babelfish database: $BBF_DATABASE_NAME"
echo "Target host: $RESTORE_HOST:$PGPORT"
echo "Roles file: $ROLES_FILE ($(du -h "$ROLES_FILE" | cut -f1))"
echo "Database file: $DB_FILE ($(du -h "$DB_FILE" | cut -f1))"
echo ""

# Test target database connectivity
echo "Testing target database connection..."
if ! psql --host="$RESTORE_HOST" --port="$PGPORT" --dbname="$PGDATABASE" --username="$PGUSER" -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✗ Cannot connect to target database server" >&2
    echo ""
    show_help
    exit 3
fi

# Check if target is a Babelfish cluster and if database exists
echo "Checking target cluster and database status..."

# First verify that $PGDATABASE exists
echo "Verifying target database exists..."
if ! psql --host="$RESTORE_HOST" --port="$PGPORT" --username="$PGUSER" -lqt | cut -d \| -f 1 | grep -qw "$PGDATABASE"; then
    echo "✗ Target database '$PGDATABASE' does not exist" >&2
    echo ""
    echo "Available databases:"
    psql --host="$RESTORE_HOST" --port="$PGPORT" --username="$PGUSER" -l
    exit 3
fi

# Now check Babelfish/T-SQL view (case insensitive)
echo "Checking Babelfish databases..."
DB_CHECK_RESULT=$(psql --host="$RESTORE_HOST" --port="$PGPORT" --dbname="$PGDATABASE" --username="$PGUSER" -t -c "SELECT name FROM sys.databases WHERE LOWER(name) = LOWER('$BBF_DATABASE_NAME');" 2>&1)

if echo "$DB_CHECK_RESULT" | grep -q "relation.*sys.databases.*does not exist"; then
    echo "✗ Target server is not a Babelfish cluster (sys.databases not found)" >&2
    exit 3
elif echo "$DB_CHECK_RESULT" | grep -q "ERROR\|FATAL"; then
    echo "✗ Error checking target database: $DB_CHECK_RESULT" >&2
    exit 3
fi

# Clean the result and check if database exists in T-SQL view
DB_EXISTS=$(echo "$DB_CHECK_RESULT" | tr -d ' \n')
if [[ -n "$DB_EXISTS" ]]; then
    echo "✗ Database '$BBF_DATABASE_NAME' already exists on target cluster" >&2
    echo ""
    echo "Current user databases on target:"
    psql --host="$RESTORE_HOST" --port="$PGPORT" --dbname="$PGDATABASE" --username="$PGUSER" -c "SELECT name AS \"Current user databases\" FROM sys.databases WHERE database_id > 4;" 2>/dev/null
    echo ""
    echo "NOTE: In newer Babelfish versions, you can rename the existing database using T-SQL:"
    echo "  1> ALTER DATABASE $BBF_DATABASE_NAME RENAME TO ${BBF_DATABASE_NAME}_old"
    echo "  2> go"
    echo "  Then run this restore script again."
    exit 4
fi

echo "✓ Target cluster is Babelfish-enabled"
echo "✓ Database '$BBF_DATABASE_NAME' does not exist on target (good)"

# Step 1: Apply roles to target cluster
echo ""
echo "Step 1: Applying T-SQL roles to target cluster..."

RESTORE_OUTPUT=$($TIME_CMD psql --host="$RESTORE_HOST" \
                              --port="$PGPORT" \
                              --dbname="$PGDATABASE" \
                              --username="$PGUSER" \
                              --single-transaction \
                              --file "$ROLES_FILE" 2>&1)

RESTORE_EXIT_CODE=$?

# Check for version mismatch errors
if echo "$RESTORE_OUTPUT" | grep -q "RAISE"; then
    echo "✗ Version mismatch or compatibility error during restore:" >&2
    echo "$RESTORE_OUTPUT" >&2
    exit 6
elif [[ $RESTORE_EXIT_CODE -ne 0 ]]; then
    echo "✗ Failed to apply roles" >&2
    echo "$RESTORE_OUTPUT" >&2
    exit 1
else
    echo "✓ Roles applied successfully"
fi

# Step 2: Restore database objects and data
echo ""
echo "Step 2: Restoring database objects and data..."

RESTORE_OUTPUT=$($TIME_CMD pg_restore --host="$RESTORE_HOST" \
                                     --port="$PGPORT" \
                                     -d "$PGDATABASE" \
                                     -U "$PGUSER" \
                                     --verbose \
                                     "$DB_FILE" 2>&1)

RESTORE_EXIT_CODE=$?

# Check for version mismatch errors
if echo "$RESTORE_OUTPUT" | grep -q "RAISE"; then
    echo "✗ Version mismatch or compatibility error during restore:" >&2
    echo "$RESTORE_OUTPUT" >&2
    exit 6
elif [[ $RESTORE_EXIT_CODE -ne 0 ]]; then
    echo "✗ Database restore failed" >&2
    echo "$RESTORE_OUTPUT" >&2
    exit 1
else
    echo "✓ Database restore completed successfully"
fi

# Final verification
echo ""
echo "Verifying restored database..."
VERIFY_RESULT=$(psql --host="$RESTORE_HOST" --port="$PGPORT" --dbname="$PGDATABASE" --username="$PGUSER" -t -c "SELECT name FROM sys.databases WHERE name = '$BBF_DATABASE_NAME';" 2>/dev/null | tr -d ' ')

if [[ "$VERIFY_RESULT" == "$BBF_DATABASE_NAME" ]]; then
    echo "✓ Database '$BBF_DATABASE_NAME' successfully created on target cluster"
else
    echo "⚠ Warning: Could not verify database creation"
fi

# Summary
echo ""
echo "=== Restore Summary ==="
echo "Database: $BBF_DATABASE_NAME"
echo "Target host: $RESTORE_HOST"
echo "Source files:"
echo "  - Roles: $ROLES_FILE"
echo "  - Data: $DB_FILE"
echo "Status: SUCCESS"
echo ""
echo "✓ Restore completed successfully"