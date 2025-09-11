# Microsoft SQL Server Tools Setup

This document explains how to install Microsoft SQL Server command line tools (sqlcmd and bcp) in the Babelfish DevContainer.

## Quick Installation

After your DevContainer is running, execute this command inside the container:

```bash
# From inside the container (as root)
bash /workspace/install_mssql_tools.sh
```

Or from the host machine:

```bash
# From host machine
docker exec -it docker-babelfishpg-devtools_devcontainer-babelfish-1 bash /workspace/install_mssql_tools.sh
```

## Testing the Installation

After installation, test sqlcmd:

```bash
# From inside container
sqlcmd -S localhost,1433 -U floorzapadmin -P secret_password -C -Q "SELECT @@version"

# From host machine
sqlcmd -S localhost,3341 -U floorzapadmin -P secret_password -C -Q "SELECT @@version"
```

**Note:** The `-C` flag is required to trust the self-signed SSL certificate.

## Expected Output

```sql
Babelfish for PostgreSQL with SQL Server Compatibility - 12.0.2000.8
Sep 10 2025 18:14:00
Copyright (c) Amazon Web Services
PostgreSQL 17.5 on x86_64-pc-linux-gnu (Babelfish 5.2.0)
```

## What Gets Installed

- **msodbcsql18** - Microsoft ODBC Driver 18 for SQL Server
- **mssql-tools18** - Command line tools including:
  - `sqlcmd` - SQL Server command line query tool
  - `bcp` - Bulk copy program

## Installation Details

The script:
1. Adds Microsoft's APT repository
2. Installs the ODBC driver and tools
3. Configures PATH environment
4. Creates symbolic links in `/usr/local/bin` for immediate access

## Troubleshooting

If sqlcmd is not found after installation:
1. Source the profile: `source /etc/profile.d/mssql.sh`
2. Or manually add to PATH: `export PATH="$PATH:/opt/mssql-tools18/bin"`

## Port Mappings

| Location | Port | Description |
|----------|------|-------------|
| Inside container | 1433 | Babelfish TDS endpoint |
| From host | 3341 | Mapped container port 1433 |

## Related Issue

This installation script addresses Issue #14 - Add Microsoft SQL Server command line tools.