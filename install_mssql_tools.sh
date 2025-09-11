#!/bin/bash
# Install Microsoft SQL Server command line tools
# This script can be run inside the container to add sqlcmd and bcp utilities

set -e

echo "Installing Microsoft SQL Server command line tools..."

# Add Microsoft GPG key
curl -s https://packages.microsoft.com/keys/microsoft.asc | apt-key add -

# Add Microsoft SQL Server Ubuntu repository
curl -s https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list

# Update package list
apt-get update

# Install MSSQL tools with automatic EULA acceptance
ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
    msodbcsql18 \
    mssql-tools18

# Clean up
rm -rf /var/lib/apt/lists/*

# Add tools to PATH
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> /etc/profile.d/mssql.sh
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> /etc/bash.bashrc

# Create symbolic links for immediate access
ln -sf /opt/mssql-tools18/bin/sqlcmd /usr/local/bin/sqlcmd
ln -sf /opt/mssql-tools18/bin/bcp /usr/local/bin/bcp

echo "MSSQL tools installation complete!"
echo ""
echo "Usage:"
echo "  sqlcmd -S localhost,1433 -U floorzapadmin -P secret_password -C -Q \"SELECT @@version\""
echo ""
echo "Note: The -C flag is required to trust the self-signed certificate"