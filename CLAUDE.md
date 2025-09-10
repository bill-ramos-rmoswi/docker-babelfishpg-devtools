# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository maintains a Docker image for Babelfish for PostgreSQL, which enables PostgreSQL to understand Microsoft SQL Server's TDS protocol and T-SQL syntax. The project is focused on building, maintaining, and distributing Docker images via Docker Hub at `jonathanpotts/babelfishpg`.

## Build Commands

### Build Docker Image Locally
```bash
# Build with default Babelfish version (specified in Dockerfile)
docker build .

# Build with specific Babelfish version
docker build . --build-arg BABELFISH_VERSION=<BABELFISH_VERSION_TAG>
```

Babelfish version tags are available at: https://github.com/babelfish-for-postgresql/babelfish-for-postgresql/tags

### Run Container
```bash
# Basic run
docker run -d -p 1433:1433 jonathanpotts/babelfishpg

# With custom credentials
docker run -d -p 1433:1433 jonathanpotts/babelfishpg -u my_username -p my_password -d my_database -m migration_mode
```

## Architecture

### Multi-Stage Dockerfile Build Process
The Dockerfile uses a multi-stage build pattern:
1. **Base Stage**: Ubuntu 22.04 foundation
2. **Builder Stage**: 
   - Installs build dependencies
   - Downloads and extracts Babelfish sources
   - Compiles ANTLR 4 runtime
   - Builds modified PostgreSQL with Babelfish extensions
   - Compiles all Babelfish contrib modules (common, money, tds, tsql)
3. **Runner Stage**: 
   - Copies compiled binaries from builder
   - Installs only runtime dependencies
   - Configures database initialization via `start.sh`

### Key Components
- **start.sh**: Entry point script that initializes the database cluster and configures Babelfish on first run
- **example_data.sql**: T-SQL script demonstrating Babelfish compatibility with SQL Server syntax
- **.github/workflows/**: Automated builds and Docker Hub publishing
  - `docker-image.yml`: Manual and PR-triggered builds
  - `babelfish-updates.yml`: Daily check for new Babelfish releases

### Important Paths
- Database data volume: `/var/lib/babelfish/data`
- Babelfish installation: `/opt/babelfish`
- Default ports: 1433 (TDS/SQL Server), 5432 (PostgreSQL)

## Breaking Changes
For versions before `BABEL_5_2_0__PG_17_5`, use the `before-BABEL_5_2_0__PG_17_5` branch.

## Default Credentials
- Username: `babelfish_user`
- Password: `12345678`
- Database: `babelfish_db`
- Migration mode: `single-db`