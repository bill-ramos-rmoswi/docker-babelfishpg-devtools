#!/bin/bash
# PostgreSQL environment variables
# This script sources .env file and sets up PostgreSQL environment

# Source .env file if it exists
if [ -f "/workspace/.devcontainer/.env" ]; then
    # Export variables from .env file (skip comments and empty lines)
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

# Set environment variables (from .env file or fallback to defaults)
export LC_ALL=${LC_ALL:-C}
export LANG=${LANG:-C}
export LANGUAGE=${LANGUAGE:-C}
export PGHOST=${PGHOST:-localhost}
export PGPORT=${PGPORT:-5432}
export PGDATABASE=${PGDATABASE:-babelfish_db}
export PGUSER=${PGUSER:-babelfish_admin}
export PGPASSWORD=${PGPASSWORD:-Dev2024_BabelfishSecure!}
export PGDATA=/var/lib/babelfish/data
export PATH=/opt/babelfish/bin:$PATH
export PGSSLMODE=require  # Enable SSL by default for secure connections
