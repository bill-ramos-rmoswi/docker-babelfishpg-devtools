#!/bin/bash
# setup-env.sh - Create .env file from template
# Purpose: Helps users set up environment configuration for Babelfish DevContainer

set -e  # Exit on any error

echo "================================================================================"
echo "Babelfish for PostgreSQL - Environment Setup"
echo "================================================================================"
echo

# Check if .env already exists
if [ -f ".devcontainer/.env" ]; then
    echo ".env file already exists in .devcontainer directory."
    echo
    read -p "Do you want to overwrite it? (y/N): " overwrite
    if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
        echo "Setup cancelled."
        exit 0
    fi
fi

# Copy template to .env
if [ -f "env.template" ]; then
    echo "Copying env.template to .devcontainer/.env..."
    if cp "env.template" ".devcontainer/.env"; then
        echo "✓ .env file created successfully!"
    else
        echo "ERROR: Failed to copy template file."
        exit 1
    fi
else
    echo "ERROR: env.template file not found."
    echo "Please ensure env.template exists in the current directory."
    exit 1
fi

echo
echo "================================================================================"
echo "Environment Configuration Created"
echo "================================================================================"
echo
echo "The .env file has been created with default values:"
echo "  Username: babelfish_admin"
echo "  Password: Dev2024_BabelfishSecure!"
echo "  Database: babelfish_db"
echo
echo "You can now:"
echo "  1. Edit .devcontainer/.env to customize your settings"
echo "  2. Run ./start_babelfish.sh to start the container"
echo
echo "⚠️  SECURITY NOTE: Never commit .env files to version control!"
echo
echo "================================================================================"
read -p "Press Enter to continue..."
