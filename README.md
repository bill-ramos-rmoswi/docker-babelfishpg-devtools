# Babelfish PostgreSQL DevTools

Enhanced Docker image for [Babelfish for PostgreSQL](https://babelfishpg.org/) development with integrated DevContainer support, development tools, and AI-assisted coding.

This project builds upon the excellent work by [Jonathan Potts](https://github.com/jonathanpotts/docker-babelfishpg), extending it with comprehensive development tools and VS Code DevContainer integration.

## What is Babelfish?

Babelfish for PostgreSQL enables PostgreSQL to understand Microsoft SQL Server's wire protocol (TDS) and T-SQL syntax, allowing applications designed for SQL Server to work with PostgreSQL with minimal changes.

## Quick Start with DevContainer (Recommended)

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- [Cursor IDE](https://cursor.com/) or [VS Code](https://code.visualstudio.com/) with Dev Containers extension
- Git

### Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/bill-ramos-rmoswi/docker-babelfishpg-devtools.git
   cd docker-babelfishpg-devtools
   ```

2. **Open in Cursor/VS Code:**
   ```bash
   cursor .  # For Cursor IDE
   # or
   code .    # For VS Code
   ```

3. **Start DevContainer:**
   - Press `F1` or `Cmd/Ctrl+Shift+P`
   - Run: `Dev Containers: Open Folder in Container`
   - Wait for build (first time: ~30-60 minutes due to compilation)

4. **Start coding!**
   - Babelfish is automatically running
   - All development tools are pre-installed
   - Claude CLI available: run `claude` for AI assistance

## Connecting to Babelfish

### Port Mappings
To avoid conflicts with local services, custom ports are used:

| Service | Container Port | Host Port | Purpose |
|---------|---------------|-----------|---------|
| Babelfish TDS | 1433 | **3341** | SQL Server protocol (T-SQL) |
| PostgreSQL | 5432 | **2345** | Native PostgreSQL |
| SSH | 22 | **2223** | Remote access |

### Connection Details

**Default Credentials:**
- Username: `babelfish_admin`
- Password: `secret_password`
- Database: `babelfish_db`

**From SQL Server Management Studio (SSMS) or Azure Data Studio:**
```
Server: localhost,3341
Authentication: SQL Server Authentication
Username: babelfish_admin
Password: secret_password
```

**From psql or PostgreSQL tools:**
```bash
psql -h localhost -p 2345 -U babelfish_admin -d babelfish_db
```

**Connection String (C#/.NET):**
```
Data Source=localhost,3341;Initial Catalog=master;User ID=babelfish_admin;Password=secret_password
```

## Features

### Pre-installed Development Tools
- **Claude CLI** - AI-assisted development (`claude` command)
- **GitHub CLI** - GitHub operations (`gh` command)
- **Node.js 20.x & npm** - JavaScript runtime
- **BabelfishDump utilities** - `bbf_dump` and `bbf_dumpall` for backups
- **PostgreSQL client tools** - Full suite of PostgreSQL utilities
- **Git** - Version control

### VS Code/Cursor Extensions (Auto-installed)
- SQL Server (ms-mssql.mssql)
- PostgreSQL (ms-ossdata.vscode-pgsql)
- Docker (ms-azuretools.vscode-docker)
- GitHub Actions (github.vscode-github-actions)
- GitLens (eamodio.gitlens)

### Backup & Restore
```bash
# Create backup
./backup_babelfish.sh babelfish_db

# Restore backup
./restore_babelfish.sh babelfish_db
```

## Standalone Docker Usage (Without DevContainer)

If you prefer to run the container without DevContainer:

```bash
# Build the image
docker build -t babelfishpg-devtools .

# Run with custom port mappings
docker run -d \
  -p 3341:1433 \
  -p 2345:5432 \
  -p 2223:22 \
  --name babelfish \
  babelfishpg-devtools

# With custom credentials
docker run -d \
  -p 3341:1433 \
  babelfishpg-devtools \
  -u my_username \
  -p my_password \
  -d my_database
```

## Data Persistence

- **Database data**: Stored in Docker volume `babelfish-data`
- **Backups**: Stored in Docker volume `babelfish-backups`
- **Workspace files**: Synced with host repository

## Development Workflow

1. **Create GitHub issue** for new feature
2. **Create feature branch**: `feature/issue-<number>-<description>`
3. **Develop in DevContainer** with all tools available
4. **Test thoroughly** using integrated tools
5. **Create Pull Request** for review

## Troubleshooting

### Port conflicts
If you see "address already in use" errors:
- These are typically IPv6 errors and can be safely ignored
- Services work on IPv4 (127.0.0.1) addresses
- Verify ports 3341, 2345, 2223 are not in use: `netstat -an | grep -E "3341|2345|2223"`

### Container won't start
- Ensure Docker Desktop is running
- Check logs: `docker logs <container-id>`
- Verify sufficient disk space and memory

### Can't connect to Babelfish
- Wait for full initialization (check container logs)
- Verify using correct ports (3341 for TDS, not 1433)
- Check firewall settings

### Rebuild DevContainer
- Press `F1` → `Dev Containers: Rebuild Container`
- For clean rebuild: `Dev Containers: Rebuild Container Without Cache`

## Example T-SQL Script

```sql
-- Create a sample database
CREATE DATABASE SampleDB;
GO

USE SampleDB;
GO

-- Create a table
CREATE TABLE Customers (
    CustomerID int PRIMARY KEY,
    FirstName nvarchar(50),
    LastName nvarchar(50),
    Email nvarchar(100)
);
GO

-- Insert sample data
INSERT INTO Customers VALUES 
    (1, 'John', 'Doe', 'john@example.com'),
    (2, 'Jane', 'Smith', 'jane@example.com');
GO

-- Query the data
SELECT * FROM Customers;
GO
```

## Project Structure

```
.
├── .devcontainer/          # DevContainer configuration
│   ├── devcontainer.json   # VS Code DevContainer settings
│   ├── docker-compose.yml  # Container orchestration
│   └── README.md           # DevContainer documentation
├── Dockerfile              # Multi-stage build configuration
├── start.sh               # Container entry point
├── backup_babelfish.sh   # Backup utility script
├── restore_babelfish.sh  # Restore utility script
├── pg_env.sh             # PostgreSQL environment setup
├── example_data.sql      # Sample T-SQL script
└── CLAUDE.md            # AI context documentation
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Acknowledgments

- Original Docker image by [Jonathan Potts](https://github.com/jonathanpotts/docker-babelfishpg)
- [Babelfish for PostgreSQL](https://babelfishpg.org/) team
- [Anthropic](https://anthropic.com/) for Claude AI assistance

## License

This project maintains the same license as the original repository. See LICENSE file for details.

## Resources

- [Babelfish Documentation](https://babelfishpg.org/docs/)
- [Cursor IDE](https://cursor.com/)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)
- [Project Issues](https://github.com/bill-ramos-rmoswi/docker-babelfishpg-devtools/issues)