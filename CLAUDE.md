# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository maintains an enhanced Docker image for Babelfish for PostgreSQL development, which enables PostgreSQL to understand Microsoft SQL Server's TDS protocol and T-SQL syntax. The project extends the base Babelfish image with development tools, backup utilities, and DevContainer support for VS Code/Cursor development.

## Development Environment - DevContainer

### Using DevContainer (Recommended)

The project includes VS Code DevContainer configuration for consistent development:

```bash
# Open in VS Code/Cursor
1. Open repository in VS Code/Cursor
2. Press F1 → "Dev Containers: Open Folder in Container"
3. Wait for build (first time: ~30-60 minutes due to compilation)
```

### DevContainer Architecture

- **Workspace**: `/workspace` in container → synced with host repository
- **Data**: Persists in Docker volumes (`babelfish-data`, `babelfish-backups`)
- **System changes**: Temporary unless added to Dockerfile

### Port Mappings (DevContainer)

| Service | Container | Host | Purpose |
|---------|-----------|------|---------|
| Babelfish TDS | 1433 | 3341 | SQL Server protocol |
| PostgreSQL | 5432 | 2345 | Native PostgreSQL |
| SSH | 22 | 2223 | Remote access |

## Build Commands

### Build Docker Image Locally
```bash
# Build with default Babelfish version (specified in Dockerfile)
docker build .

# Build with specific Babelfish version
docker build . --build-arg BABELFISH_VERSION=<BABELFISH_VERSION_TAG>

# Build DevContainer
docker-compose -f .devcontainer/docker-compose.yml build
```

### Run Container
```bash
# Basic run (standalone)
docker run -d -p 3341:1433 -p 2345:5432 docker-babelfishpg-devtools

# With custom credentials
docker run -d -p 3341:1433 docker-babelfishpg-devtools -u my_username -p my_password -d my_database -m migration_mode

# DevContainer (via Docker Compose)
docker-compose -f .devcontainer/docker-compose.yml up
```

## Architecture

### Multi-Stage Dockerfile Build Process
1. **Base Stage**: Ubuntu 22.04 foundation
2. **Builder Stage**: 
   - Installs build dependencies
   - Downloads and extracts Babelfish sources
   - Compiles ANTLR 4 runtime
   - Builds modified PostgreSQL with Babelfish extensions
   - Compiles all Babelfish contrib modules (common, money, tds, tsql)
   - Builds BabelfishDump utilities (bbf_dump, bbf_dumpall)
3. **Runner Stage**: 
   - Copies compiled binaries from builder
   - Installs runtime dependencies
   - Configures SSH server
   - Sets up database initialization via `start.sh`

### Key Components
- **start.sh**: Enhanced entry point script with proper permission handling and user creation
- **backup_babelfish.sh**: Automated backup script using bbf_dump utilities
- **restore_babelfish.sh**: Restore script for bbf_dump backups
- **pg_env.sh**: PostgreSQL environment variables
- **.devcontainer/**: VS Code DevContainer configuration
- **example_data.sql**: T-SQL script demonstrating Babelfish compatibility

### Important Paths
- Workspace (in DevContainer): `/workspace`
- Database data volume: `/var/lib/babelfish/data`
- Backup directory: `/var/lib/babelfish/bbf_backups`
- Babelfish installation: `/opt/babelfish`
- BabelfishDump utilities: `/opt/babelfish/bin/bbf_dump*`

## Credentials and Configuration

### Updated Default Credentials
- **Username**: `babelfish_admin` (superuser)
- **Password**: `secret_password`
- **Database**: `babelfish_db`
- **Migration mode**: `multi-db`

### Connection Examples
```bash
# From host machine (DevContainer running)
psql -h localhost -p 2345 -U babelfish_admin -d babelfish_db

# SQL Server tools (when installed)
sqlcmd -S localhost,3341 -U babelfish_admin -P secret_password

# Inside container
psql -U babelfish_admin -d babelfish_db
```

## Common Issues and Solutions

### Issue: Container permission errors
**Solution**: Container now starts as root and switches to postgres user after fixing permissions

### Issue: "role babelfish_admin does not exist"
**Solution**: Fixed in start.sh - user creation now properly executes as postgres user with heredoc syntax

### Issue: Container exits immediately
**Solution**: Check logs with `docker logs <container-id>` - usually permission issues on volumes

### Issue: Port conflicts
**Solution**: Use mapped ports (3341, 2345, 2223) instead of default ports

## Development Workflow

### Working with Issues and PRs
1. Create GitHub issue for feature
2. Create feature branch: `feature/issue-<number>-<description>`
3. Develop iteratively in DevContainer
4. Test thoroughly
5. Create PR for review

### Making System Changes Permanent
```bash
# Option 1: Add to Dockerfile
echo "RUN apt-get install -y <package>" >> Dockerfile

# Option 2: Add to devcontainer.json
"postCreateCommand": "sudo apt-get install -y <package>"

# Option 3: Create setup script in workspace
```

## Testing Commands

### Verify Babelfish Installation
```bash
# Check version
psql -U babelfish_admin -d babelfish_db -c "SELECT @@version"

# Test TDS connection
tsql -S localhost -p 1433 -U babelfish_admin -P secret_password

# List databases (T-SQL style)
psql -U babelfish_admin -d babelfish_db -c "SELECT name FROM sys.databases"
```

### Backup and Restore Testing
```bash
# Create backup
./backup_babelfish.sh babelfish_db

# Restore backup
./restore_babelfish.sh babelfish_db
```

## Features in Development

### Completed
- ✅ DevContainer support (Issue #7)
- ✅ BabelfishDump utilities integration (Issue #2)
- ✅ Enhanced start.sh with proper permissions
- ✅ Backup/restore scripts
- ✅ PostgreSQL VS Code extension
- ✅ Security improvements (.gitignore)

### In Progress
- 🔄 Dockerfile multi-stage optimization (Issue #1)
- 🔄 SSH server configuration (Issue #3)

### Planned
- 📋 Babelfish Compass integration (Issue #4)
- 📋 AWS CLI v2 (Issue #5)
- 📋 Liquibase for schema management (Issue #6)
- 📋 Microsoft SQL Server tools (Issue #14)
- 📋 Directory structure reorganization (Issue #8)
- 📋 S3 backup/restore support (Issue #9)

## Important Notes

- **Build time**: First build takes 30-60 minutes due to compiling Babelfish from source
- **Caching**: Subsequent builds are faster due to Docker layer caching
- **Volumes**: Database data persists in Docker volumes, survives container rebuilds
- **Permissions**: Container runs as root initially to fix permissions, then switches to postgres
- **Breaking changes**: For versions before `BABEL_5_2_0__PG_17_5`, use the `before-BABEL_5_2_0__PG_17_5` branch

## Working Guidelines

- Work iteratively on each section to ensure features work in the container
- Use feature branches tied to GitHub issues
- Create comprehensive plans in GitHub issues before implementation
- Test all changes in DevContainer before creating PR
- Document new features in both CLAUDE.md and README files
- Keep security in mind - use .gitignore for sensitive files