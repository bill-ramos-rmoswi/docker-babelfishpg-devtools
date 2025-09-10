# Babelfish DevTools DevContainer

This directory contains the configuration for VS Code Dev Containers, providing a consistent development environment for working with Babelfish for PostgreSQL.

## Quick Start

### Prerequisites
- Docker Desktop installed and running
- VS Code or Cursor with the "Dev Containers" extension
- Git configured on your host machine

### Opening in DevContainer

1. **VS Code/Cursor:**
   - Open this repository in VS Code/Cursor
   - Press `F1` or `Ctrl+Shift+P` (Windows/Linux) or `Cmd+Shift+P` (Mac)
   - Run command: `Dev Containers: Open Folder in Container`
   - Wait for the container to build (first time may take 10-15 minutes)

2. **Command Line:**
   ```bash
   code . --folder-uri vscode-remote://dev-container+$(pwd)
   ```

## Port Mappings

To avoid conflicts with local services, the following ports are mapped:

| Service | Container Port | Host Port | Description |
|---------|---------------|-----------|-------------|
| Babelfish TDS | 1433 | 3341 | SQL Server protocol (T-SQL) |
| PostgreSQL | 5432 | 2345 | Native PostgreSQL connection |
| SSH | 22 | 2223 | SSH access to container |

## Connecting to Babelfish

### From SQL Server Management Studio (SSMS) or Azure Data Studio:
- **Server:** `localhost,3341`
- **Authentication:** SQL Server Authentication
- **Username:** `babelfish_admin`
- **Password:** `secret_password`
- **Database:** `master` (or your T-SQL database)

### From psql or PostgreSQL tools:
```bash
psql -h localhost -p 2345 -U babelfish_admin -d babelfish_db
```

### From within the container:
```bash
# T-SQL via sqlcmd (when available)
sqlcmd -S localhost,1433 -U babelfish_admin -P secret_password

# PostgreSQL native
psql -h localhost -p 5432 -U babelfish_admin -d babelfish_db
```

## SSH Access

To SSH into the running container:
```bash
ssh -p 2223 postgres@localhost
# Default password: postgres
```

## Development Workflow

### For VS Code/Cursor Users:
1. All terminal commands run inside the container
2. File changes are automatically synced
3. Git operations work seamlessly
4. Extensions are pre-configured

### For Claude Code Users:
1. Continue editing from your WSL/host environment
2. Files at `/mnt/c/Users/rmosw/source/bill-ramos-rmoswi/docker-babelfishpg-devtools/`
3. Changes reflect immediately in the container
4. Use VS Code/Cursor terminal for testing commands in container

## How DevContainer Works

### Architecture Overview

When you connect to the DevContainer, Cursor (or VS Code) actually runs **inside** the container, not remotely connecting to it. Here's how it works:

1. **Cursor Runs Inside the Container**
   - Cursor installs a "server" component inside the container
   - Your local Cursor acts as a client connecting to this server
   - All terminal commands, file operations, and extensions run inside the container

2. **File System Architecture**
   ```
   Host Machine (Windows)                Container (Linux)
   ├── C:\...\docker-babelfishpg-devtools → /workspace (bind mount)
   │   ├── .devcontainer/                  ├── Same files, synced
   │   ├── Dockerfile                      ├── Same files, synced
   │   └── *.sh scripts                    └── Same files, synced
   │
   └── [Your local files]                  /var/lib/babelfish/data (volume)
                                          /opt/babelfish/ (container only)
                                          /usr/bin/ (container only)
   ```

### What You Can Change

#### 1. **Workspace Files (Persistent)**
- **Location**: `/workspace` in container → `C:\...\docker-babelfishpg-devtools` on host
- **Changes**: Automatically synced bidirectionally
- **Persistence**: Permanent - survives container rebuilds
- Examples: Editing scripts, Dockerfile, source code

#### 2. **Container System Files (Temporary)**
- **Location**: `/usr/bin`, `/etc`, `/opt/babelfish`, etc.
- **Changes**: Only exist in running container
- **Persistence**: Lost when container stops/rebuilds
- Examples:
  ```bash
  # Inside container terminal in Cursor:
  sudo apt install vim  # Lost on rebuild
  echo "alias ll='ls -la'" >> ~/.bashrc  # Lost on rebuild
  sudo systemctl restart ssh  # Affects current session only
  ```

#### 3. **Volume Data (Persistent)**
- **Location**: `/var/lib/babelfish/data`, `/var/lib/babelfish/bbf_backups`
- **Changes**: Persist in Docker volumes
- **Persistence**: Survives container restart, lost only if volume deleted
- Examples: Database data, backups

### Making Container Changes Permanent

To make system-level changes permanent, you have three options:

1. **Add to Dockerfile** (Rebuild required)
   ```dockerfile
   RUN apt-get install -y vim postgresql-client
   ```

2. **Add to postCreateCommand** in devcontainer.json
   ```json
   "postCreateCommand": "sudo apt-get update && sudo apt-get install -y vim"
   ```

3. **Create setup script** in workspace
   ```bash
   # /workspace/setup-dev-tools.sh
   #!/bin/bash
   sudo apt-get update
   sudo apt-get install -y vim htop
   ```

### The Connection Flow

```
1. Open Cursor → "Open Folder in Container"
2. Cursor reads .devcontainer/devcontainer.json
3. Docker Compose builds/starts container
4. Cursor installs VS Code Server in container
5. Your Cursor window connects to container
6. Terminal runs inside container as postgres user
7. File edits in /workspace sync to host
8. Extensions run inside container
```

### Practical Examples

**Testing Changes:**
```bash
# In Cursor terminal (inside container):
which psql  # /opt/babelfish/bin/psql
pwd  # /workspace
whoami  # postgres or root

# Install something temporarily
sudo apt install tree
tree /opt/babelfish  # Works until rebuild

# Make permanent change
echo "RUN apt-get install -y tree" >> /workspace/Dockerfile
# Then rebuild container
```

**Database Access:**
```bash
# Inside container - direct access
psql -U babelfish_admin -d babelfish_db

# From host - through mapped ports
psql -h localhost -p 2345 -U babelfish_admin
```

### Key Insights

- **Cursor becomes a Linux development environment** running inside the container
- **Your files stay safely on Windows**, synced via the bind mount
- **Database changes persist** in Docker volumes
- **System changes are temporary** unless added to Dockerfile or scripts
- **Port mappings** allow access from both inside and outside the container

## Pre-installed VS Code Extensions

- **ms-mssql.mssql** - SQL Server connections and T-SQL IntelliSense
- **ms-azuretools.vscode-docker** - Docker management
- **redhat.vscode-yaml** - YAML syntax support
- **github.vscode-github-actions** - GitHub Actions support
- **eamodio.gitlens** - Enhanced Git features

## Environment Variables

The following environment variables are configured in the container:

- `PGHOST=localhost`
- `PGPORT=5432`
- `PGDATABASE=babelfish_db`
- `PGUSER=babelfish_admin`
- `PGPASSWORD=secret_password`

## Volumes

Two Docker volumes are created to persist data:

- `babelfish-data` - PostgreSQL/Babelfish data directory
- `babelfish-backups` - Backup files location

## Troubleshooting

### Container won't start
- Check Docker Desktop is running
- Ensure ports 3341, 2345, 2223 are not in use: `netstat -an | grep -E "3341|2345|2223"`

### Can't connect to Babelfish
- Wait for container to fully start (check logs)
- Verify port mappings are correct
- Check firewall settings

### Permission issues
- The container runs as `postgres` user (UID 1000)
- Files created in container will be owned by this user

### Rebuild container
If you need to rebuild after Dockerfile changes:
```bash
# VS Code command palette
Dev Containers: Rebuild Container

# Or from terminal
docker-compose -f .devcontainer/docker-compose.yml build --no-cache
```

## Additional Resources

- [VS Code Dev Containers Documentation](https://code.visualstudio.com/docs/devcontainers/containers)
- [Babelfish for PostgreSQL Documentation](https://babelfishpg.org/docs/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)