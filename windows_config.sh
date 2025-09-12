#!/bin/bash
# windows_config.sh - Environment configuration for Windows Docker integration
# Purpose: Set up environment variables for Windows backup paths and Docker volumes
# Usage: source windows_config.sh
#
# This script configures the environment to work with both Docker named volumes
# and Windows host-mounted directories for backup operations.

# Determine if we're running inside Docker container
if [[ -f /.dockerenv ]]; then
    IN_CONTAINER=true
    CONTAINER_USER=$(whoami)
else
    IN_CONTAINER=false
    CONTAINER_USER="unknown"
fi

echo "=================================================================================="
echo "Babelfish Windows Docker Configuration"
echo "=================================================================================="
echo "Container: $IN_CONTAINER"
echo "User: $CONTAINER_USER"
echo

# Database connection settings (from docker-compose environment)
export PGHOST=${PGHOST:-localhost}
export PGPORT=${PGPORT:-5432}
export PGDATABASE=${PGDATABASE:-babelfish_db}
export PGUSER=${PGUSER:-babelfish_admin}
export PGPASSWORD=${PGPASSWORD:-secret_password}

# Babelfish paths
export BABELFISH_HOME=${BABELFISH_HOME:-/opt/babelfish}
export BABELFISH_DATA=${BABELFISH_DATA:-/var/lib/babelfish/data}
export BABELFISH_BIN=${BABELFISH_BIN:-${BABELFISH_HOME}/bin}

# Backup directory configurations
if [[ "$IN_CONTAINER" == true ]]; then
    # Inside container - use container paths
    export BBF_DOCKER_BACKUPS=${BBF_DOCKER_BACKUPS:-/var/lib/babelfish/bbf_backups}
    export BBF_WINDOWS_BACKUPS=${BBF_WINDOWS_BACKUPS:-/var/lib/babelfish/windows_backups}
    
    # Try to detect the Windows user from the mount point
    if [[ -d "$BBF_WINDOWS_BACKUPS" ]]; then
        WINDOWS_USER=$(stat -c %U "$BBF_WINDOWS_BACKUPS" 2>/dev/null || echo "unknown")
        export BBF_HOST_BACKUP_PATH=${BBF_HOST_BACKUP_PATH:-/mnt/c/Users/$WINDOWS_USER/bbf_backups}
    else
        export BBF_HOST_BACKUP_PATH=${BBF_HOST_BACKUP_PATH:-/mnt/c/Users/user/bbf_backups}
    fi
    
    # Set default backup location for existing scripts
    # This allows backup_babelfish.sh and restore_babelfish.sh to work unchanged
    if [[ -d "$BBF_WINDOWS_BACKUPS" ]]; then
        # Use Windows mount if available
        export HOME_BACKUP_DIR="$BBF_WINDOWS_BACKUPS"
        export BACKUP_BASE_DIR="$BBF_WINDOWS_BACKUPS"
    else
        # Fall back to Docker volume
        export HOME_BACKUP_DIR="$BBF_DOCKER_BACKUPS"
        export BACKUP_BASE_DIR="$BBF_DOCKER_BACKUPS"
    fi
else
    # Outside container - use host paths
    export BBF_HOST_BACKUP_PATH="/mnt/c/Users/$(whoami)/bbf_backups"
    export HOME_BACKUP_DIR="$HOME/bbf_backups"
    export BACKUP_BASE_DIR="$HOME/bbf_backups"
fi

# Additional environment for backup scripts compatibility
export BBF_CONFIG_LOADED=true

# Function to show backup directory status
show_backup_status() {
    echo "Backup Directory Status:"
    echo "========================"
    
    if [[ "$IN_CONTAINER" == true ]]; then
        echo "Docker Volume Backups:"
        if [[ -d "$BBF_DOCKER_BACKUPS" ]]; then
            echo "  ✓ $BBF_DOCKER_BACKUPS"
            echo "    $(ls -la "$BBF_DOCKER_BACKUPS" 2>/dev/null | wc -l) items"
        else
            echo "  ✗ $BBF_DOCKER_BACKUPS (not found)"
        fi
        
        echo "Windows Host Backups:"
        if [[ -d "$BBF_WINDOWS_BACKUPS" ]]; then
            echo "  ✓ $BBF_WINDOWS_BACKUPS"
            echo "    $(ls -la "$BBF_WINDOWS_BACKUPS" 2>/dev/null | wc -l) items"
            echo "    Maps to: $BBF_HOST_BACKUP_PATH"
        else
            echo "  ✗ $BBF_WINDOWS_BACKUPS (not mounted)"
            echo "    Expected Windows path: $BBF_HOST_BACKUP_PATH"
        fi
        
        echo "Active Backup Directory:"
        echo "  → $BACKUP_BASE_DIR"
    else
        echo "Host Backup Directory:"
        if [[ -d "$HOME_BACKUP_DIR" ]]; then
            echo "  ✓ $HOME_BACKUP_DIR"
        else
            echo "  ✗ $HOME_BACKUP_DIR (not found)"
        fi
    fi
}

# Function to create backup directories
create_backup_dirs() {
    echo "Creating backup directories..."
    
    if [[ "$IN_CONTAINER" == true ]]; then
        # Create Docker volume backup dir
        if [[ ! -d "$BBF_DOCKER_BACKUPS" ]]; then
            mkdir -p "$BBF_DOCKER_BACKUPS"
            echo "✓ Created: $BBF_DOCKER_BACKUPS"
        fi
        
        # Create Windows backup dir (may fail if mount not available)
        if [[ ! -d "$BBF_WINDOWS_BACKUPS" ]]; then
            mkdir -p "$BBF_WINDOWS_BACKUPS" 2>/dev/null && \
                echo "✓ Created: $BBF_WINDOWS_BACKUPS" || \
                echo "⚠ Cannot create: $BBF_WINDOWS_BACKUPS (mount may not be available)"
        fi
        
        # Fix permissions
        chown -R postgres:postgres "$BBF_DOCKER_BACKUPS" 2>/dev/null || true
        chown -R postgres:postgres "$BBF_WINDOWS_BACKUPS" 2>/dev/null || true
    else
        # Create host backup directory
        if [[ ! -d "$HOME_BACKUP_DIR" ]]; then
            mkdir -p "$HOME_BACKUP_DIR"
            echo "✓ Created: $HOME_BACKUP_DIR"
        fi
    fi
}

# Function to switch backup location
switch_backup_location() {
    local location="$1"
    
    case "$location" in
        "docker"|"volume")
            export BACKUP_BASE_DIR="$BBF_DOCKER_BACKUPS"
            export HOME_BACKUP_DIR="$BBF_DOCKER_BACKUPS"
            echo "Switched to Docker volume backups: $BACKUP_BASE_DIR"
            ;;
        "windows"|"host")
            if [[ -d "$BBF_WINDOWS_BACKUPS" ]]; then
                export BACKUP_BASE_DIR="$BBF_WINDOWS_BACKUPS"
                export HOME_BACKUP_DIR="$BBF_WINDOWS_BACKUPS"
                echo "Switched to Windows host backups: $BACKUP_BASE_DIR"
            else
                echo "ERROR: Windows backup mount not available: $BBF_WINDOWS_BACKUPS"
                return 1
            fi
            ;;
        *)
            echo "ERROR: Invalid backup location. Use 'docker' or 'windows'"
            return 1
            ;;
    esac
}

# Show current configuration
echo "Environment Configuration:"
echo "=========================="
echo "PGHOST=$PGHOST"
echo "PGPORT=$PGPORT"
echo "PGDATABASE=$PGDATABASE"
echo "PGUSER=$PGUSER"
echo "BABELFISH_HOME=$BABELFISH_HOME"
echo
if [[ "$IN_CONTAINER" == true ]]; then
    echo "Docker Backups: $BBF_DOCKER_BACKUPS"
    echo "Windows Backups: $BBF_WINDOWS_BACKUPS"
    echo "Host Path: $BBF_HOST_BACKUP_PATH"
    echo
fi
echo "Active Backup Dir: $BACKUP_BASE_DIR"
echo

# Show backup status
show_backup_status

echo
echo "Available Functions:"
echo "===================="
echo "show_backup_status       - Show current backup directory status"
echo "create_backup_dirs       - Create backup directories"
echo "switch_backup_location   - Switch between docker/windows backup locations"
echo
echo "Usage Examples:"
echo "  switch_backup_location windows    # Use Windows host mount"
echo "  switch_backup_location docker     # Use Docker named volume"
echo "  create_backup_dirs               # Create missing directories"
echo
echo "Configuration loaded successfully!"
echo "=================================================================================="