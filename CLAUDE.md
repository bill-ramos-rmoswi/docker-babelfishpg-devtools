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
4. Claude CLI is pre-installed - run 'claude' to start AI-assisted development
5. Use '/summary' in Claude to load this CLAUDE.md context
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

### Multi-Stage Dockerfile Build Process (Refactored in PR #17)
The Dockerfile uses an optimized 6-stage build pattern for better caching and maintainability:

1. **base**: Ubuntu 22.04 foundation
   - Minimal base image
   - DEBIAN_FRONTEND=noninteractive

2. **build-deps**: All build dependencies in one cacheable layer
   - Core build tools (gcc, cmake, etc.)
   - PostgreSQL build dependencies
   - ANTLR/Java dependencies
   - BabelfishDump dependencies
   - Single apt-get install for optimal caching

3. **antlr-builder**: ANTLR 4 runtime compilation
   - Builds ANTLR C++ runtime
   - Isolated from other build processes

4. **postgres-builder**: PostgreSQL/Babelfish compilation
   - Downloads Babelfish sources
   - Configures and builds PostgreSQL
   - Builds all Babelfish extensions
   - Uses loop for building modules

5. **bbfdump-builder**: BabelfishDump utilities build
   - Clones postgresql_modified_for_babelfish repo
   - Builds RPM and converts to DEB
   - Isolated for independent updates

6. **runner**: Final runtime image
   - Copies binaries from builder stages
   - Installs runtime dependencies only
   - Configures SSH, Node.js, Claude CLI
   - Sets up permissions and volumes

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

## Adding New Tools to the Container

Following the multi-stage pattern established in PR #17, here's how to add new tools:

### Where to Add Dependencies

#### Build-Time Dependencies (Stage: build-deps)
Add to the `build-deps` stage if the tool is needed ONLY during compilation:
```dockerfile
FROM base AS build-deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Existing dependencies...
    # Add new build dependency here
    new-build-tool \
    && rm -rf /var/lib/apt/lists/*
```

#### Runtime Tools (Stage: runner)
Add to the `runner` stage if the tool is needed in the final container:

**For APT packages:**
```dockerfile
# In the runtime dependencies section (around line 230)
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Existing packages...
    # Add new runtime tool
    sqlcmd \  # Example: MSSQL command line tools
    && rm -rf /var/lib/apt/lists/*
```

**For tools requiring special installation (like AWS CLI, Node packages):**
```dockerfile
# Add as a separate RUN command after runtime dependencies
# Example: AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws/
```

### Examples for Common Additions

#### Adding MSSQL Tools (Issue #14)
```dockerfile
# In runner stage, after base runtime dependencies:
# Install Microsoft SQL Server command line tools
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
    msodbcsql18 \
    mssql-tools18 \
    && rm -rf /var/lib/apt/lists/* && \
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> /etc/profile.d/mssql.sh
```

#### Adding AWS CLI v2 and SSM Plugin (Issue #5)
```dockerfile
# In runner stage, as separate RUN command:
# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws/

# Install SSM Session Manager Plugin
RUN curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb" && \
    dpkg -i session-manager-plugin.deb && \
    rm session-manager-plugin.deb
```

### Best Practices

1. **Group related installations** to minimize layers
2. **Clean up after installation** with `rm -rf /var/lib/apt/lists/*` for apt
3. **Use --no-install-recommends** to minimize image size
4. **Add build arguments** for configurable versions:
   ```dockerfile
   ARG AWS_CLI_VERSION=latest
   ```
5. **Document each addition** with comments
6. **Test incrementally** - build after each addition
7. **Consider layer caching** - put frequently changing items last

### Testing New Additions
```bash
# Build and test locally
docker build -t test-image .
docker run -it test-image /bin/bash

# Inside container, verify tool installation
which aws
sqlcmd -?
```

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

### Test MSSQL Tools (Issue #14)
```bash
# Verify sqlcmd installation
sqlcmd -?

# Connect to Babelfish using sqlcmd
sqlcmd -S localhost,1433 -U babelfish_admin -P secret_password -Q "SELECT @@version"

# Test bcp utility
bcp --version

# Environment should include MSSQL tools in PATH
echo $PATH | grep mssql-tools18
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
- ✅ Claude CLI integration (Issue #15)
- ✅ Dockerfile multi-stage optimization (Issue #1)

### In Progress
- 🔄 SSH server configuration (Issue #3)
- 🔄 Microsoft SQL Server tools (Issue #14) - Implementation complete, testing pending

### Planned
- 📋 Babelfish Compass integration (Issue #4)
- 📋 AWS CLI v2 (Issue #5)
- 📋 Liquibase for schema management (Issue #6)
- 📋 Directory structure reorganization (Issue #8)
- 📋 S3 backup/restore support (Issue #9)

## Current Work Status (Issue #14 - MSSQL Tools)

### What's Been Done
- ✅ Created feature branch: `feature/issue-14-mssql-tools`
- ✅ Added MSSQL tools installation to Dockerfile (lines 277-286)
- ✅ Configured PATH for sqlcmd and bcp tools
- ✅ Added ACCEPT_EULA=Y for unattended installation

### Next Steps for Host Machine
1. **Rebuild DevContainer** from Cursor/VS Code:
   - Close the current DevContainer
   - Run: `Dev Containers: Rebuild Container`
   - This will use the updated Dockerfile with MSSQL tools

2. **Test MSSQL Tools** after rebuild:
   ```bash
   # Inside rebuilt container
   sqlcmd -?
   sqlcmd -S localhost,1433 -U babelfish_admin -P secret_password
   bcp --version
   ```

3. **If tests pass**, create PR:
   ```bash
   git add Dockerfile CLAUDE.md
   git commit -m "feat: Add Microsoft SQL Server command line tools (Issue #14)"
   git push origin feature/issue-14-mssql-tools
   # Then create PR via GitHub
   ```

### Known Status
- Branch is currently on `feature/issue-14-mssql-tools`
- Changes are staged but not yet committed
- Testing requires DevContainer rebuild from host

## Important Notes

- **Build time**: First build takes 30-60 minutes due to compiling Babelfish from source
- **Caching**: Subsequent builds are faster due to Docker layer caching (optimized in PR #17 with 6-stage build)
- **Volumes**: Database data persists in Docker volumes, survives container rebuilds
- **Permissions**: Container runs as root initially to fix permissions, then switches to postgres
- **Breaking changes**: For versions before `BABEL_5_2_0__PG_17_5`, use the `before-BABEL_5_2_0__PG_17_5` branch
- **Dockerfile stages**: As of PR #17, uses 6 stages (base, build-deps, antlr-builder, postgres-builder, bbfdump-builder, runner)

## Working Guidelines

- Work iteratively on each section to ensure features work in the container
- Use feature branches tied to GitHub issues
- Create comprehensive plans in GitHub issues before implementation
- Test all changes in DevContainer before creating PR
- Document new features in both CLAUDE.md and README files
- Keep security in mind - use .gitignore for sensitive files