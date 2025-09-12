#!/bin/bash
# fix_permissions.sh - Fix Docker volume ownership and permissions
# Purpose: Resolve permission issues between Windows host and Linux container
# Usage: ./fix_permissions.sh [--windows-backups] [--all]
#
# This script addresses common Docker volume permission issues when working
# with Windows hosts and Linux containers, especially for backup directories
# and database data files.

set -e

show_help() {
    cat << EOF
fix_permissions.sh - Fix Docker volume ownership and permissions

USAGE:
    $(basename "$0") [OPTIONS]

DESCRIPTION:
    Fixes ownership and permission issues that commonly occur when using
    Docker volumes with Windows hosts and Linux containers. This is especially
    important for backup operations and database data access.

OPTIONS:
    -h, --help              Show this help message and exit
    -w, --windows-backups   Fix permissions on Windows backup mount only
    -a, --all              Fix all permissions (data, backups, logs)
    -v, --verbose          Show detailed output

DIRECTORIES FIXED:
    /var/lib/babelfish/data              - PostgreSQL database data
    /var/lib/babelfish/bbf_backups       - Docker volume backups  
    /var/lib/babelfish/windows_backups   - Windows host mount backups
    /var/lib/babelfish/data/log          - PostgreSQL log files

EXAMPLES:
    $(basename "$0")                     # Fix core database permissions
    $(basename "$0") --all               # Fix all permissions
    $(basename "$0") --windows-backups   # Fix only Windows mount permissions

EXIT CODES:
    0    Success
    1    General error
    2    Permission denied (may need to run as root)

EOF
}

# Default options
FIX_WINDOWS=false
FIX_ALL=false
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -w|--windows-backups)
            FIX_WINDOWS=true
            shift
            ;;
        -a|--all)
            FIX_ALL=true
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
echo "Babelfish Docker Volume Permission Fixer"
echo "=================================================================================="
echo

# Check if running in container
if [[ ! -f /.dockerenv ]]; then
    echo "WARNING: This script is designed to run inside the Docker container."
    echo "Run this script using:"
    echo "  docker-compose exec babelfish ./fix_permissions.sh"
    echo
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Check if we have root privileges for critical operations
if [[ $EUID -ne 0 ]] && [[ "$FIX_ALL" == true || "$1" == "" ]]; then
    echo "ERROR: Root privileges required for fixing database permissions."
    echo "Run with: docker-compose exec --user root babelfish ./fix_permissions.sh"
    exit 2
fi

# Core database permissions (requires root)
if [[ "$FIX_ALL" == true || ("$FIX_WINDOWS" == false && "$1" == "") ]]; then
    echo "Fixing core database permissions..."
    
    if [[ -d "/var/lib/babelfish/data" ]]; then
        log_verbose "Setting ownership: /var/lib/babelfish/data -> postgres:postgres"
        chown -R postgres:postgres /var/lib/babelfish/data
        
        log_verbose "Setting permissions: /var/lib/babelfish/data -> 700"
        chmod 700 /var/lib/babelfish/data
        
        # Fix log directory permissions
        if [[ -d "/var/lib/babelfish/data/log" ]]; then
            log_verbose "Setting log directory permissions"
            chown postgres:postgres /var/lib/babelfish/data/log
            chmod 700 /var/lib/babelfish/data/log
        fi
        
        echo "✓ Database data permissions fixed"
    else
        echo "⚠ Database data directory not found: /var/lib/babelfish/data"
    fi
    
    # Docker backup volume permissions
    if [[ -d "/var/lib/babelfish/bbf_backups" ]]; then
        log_verbose "Setting ownership: /var/lib/babelfish/bbf_backups -> postgres:postgres"
        chown -R postgres:postgres /var/lib/babelfish/bbf_backups
        
        log_verbose "Setting permissions: /var/lib/babelfish/bbf_backups -> 755"
        chmod 755 /var/lib/babelfish/bbf_backups
        
        echo "✓ Docker backup directory permissions fixed"
    else
        echo "⚠ Docker backup directory not found: /var/lib/babelfish/bbf_backups"
    fi
fi

# Windows backup mount permissions (can run as any user)
if [[ "$FIX_WINDOWS" == true || "$FIX_ALL" == true ]]; then
    echo "Fixing Windows backup mount permissions..."
    
    if [[ -d "/var/lib/babelfish/windows_backups" ]]; then
        # Create directory structure if needed
        log_verbose "Ensuring directory structure exists"
        mkdir -p /var/lib/babelfish/windows_backups
        
        # Set permissions to allow postgres user access
        if [[ $EUID -eq 0 ]]; then
            log_verbose "Setting ownership: /var/lib/babelfish/windows_backups -> postgres:postgres"
            chown -R postgres:postgres /var/lib/babelfish/windows_backups
        fi
        
        log_verbose "Setting permissions: /var/lib/babelfish/windows_backups -> 755"
        chmod -R 755 /var/lib/babelfish/windows_backups 2>/dev/null || true
        
        echo "✓ Windows backup mount permissions fixed"
    else
        echo "⚠ Windows backup mount not found: /var/lib/babelfish/windows_backups"
        echo "  This is normal if the Windows host directory doesn't exist yet."
    fi
fi

echo
echo "Permission fix completed!"
echo

# Show status
echo "Directory Status:"
echo "=================="

for dir in "/var/lib/babelfish/data" "/var/lib/babelfish/bbf_backups" "/var/lib/babelfish/windows_backups"; do
    if [[ -d "$dir" ]]; then
        owner=$(ls -ld "$dir" | awk '{print $3":"$4}')
        perms=$(ls -ld "$dir" | awk '{print $1}')
        echo "  $dir"
        echo "    Owner: $owner"
        echo "    Permissions: $perms"
    else
        echo "  $dir - NOT FOUND"
    fi
done

echo
echo "=================================================================================="
echo "If you continue to have permission issues:"
echo "  1. Ensure Windows backup directory exists: C:\\Users\\%USERNAME%\\bbf_backups"
echo "  2. Run: docker-compose down && docker-compose up -d"
echo "  3. Run this script again with --all option"
echo "=================================================================================="