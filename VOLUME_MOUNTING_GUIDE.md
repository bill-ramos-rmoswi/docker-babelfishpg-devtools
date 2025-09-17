# Volume Mounting Guide for Docker Babelfish Development Tools

This guide explains how to properly configure volume mounting for backup files between your Windows host and the Docker container.

## Overview

The Docker setup provides two backup directory options:

1. **Windows-accessible backup directory**: `C:\Users\%USERNAME%\bbf_backups` → `/home/postgres/bbf_backups`
2. **Docker named volume**: `babelfish-backups` → `/var/lib/babelfish/bbf_backups`

## Configuration

### Docker Compose Volume Mapping

The `docker-compose.yml` file maps your Windows backup directory to the container:

```yaml
volumes:
  # Windows-accessible backup directory (host mount)
  # This maps Windows C:\Users\%USERNAME%\bbf_backups to container /home/postgres/bbf_backups
  - C:/Users/${USERNAME}/bbf_backups:/home/postgres/bbf_backups:rw
```

### Backup Directory Discovery

The `restore_babelfish.sh` script automatically discovers backup files using this priority order:

1. `/home/postgres/bbf_backups` (Windows-mounted directory)
2. `$HOME/bbf_backups` (user home directory)
3. `/var/lib/babelfish/bbf_backups` (Docker named volume)

## Usage

### 1. Create Windows Backup Directory

Create the backup directory on your Windows host:

```cmd
mkdir C:\Users\%USERNAME%\bbf_backups
```

### 2. Place Backup Files

Organize your backup files in the following structure:

```
C:\Users\%USERNAME%\bbf_backups\
└── your_database_name\
    └── YYYY-MM-DD_HHMM\
        ├── your_database_name.tar      (bbf_dump output)
        └── your_database_name.pgsql    (bbf_dumpall output)
```

### 3. Test Volume Mounting

Run the test script inside the container to verify mounting:

```bash
# Inside the container
./test-volume-mount.sh
```

### 4. Run Restore Script

The restore script will automatically find your backup files:

```bash
# Inside the container
restore_babelfish.sh your_database_name
```

## Troubleshooting

### Volume Not Mounting

1. **Check Windows path exists**: Ensure `C:\Users\%USERNAME%\bbf_backups` exists
2. **Check Docker Desktop**: Ensure Docker Desktop is running and has file sharing enabled
3. **Check permissions**: Ensure the directory is accessible

### Permission Issues

If you encounter permission issues:

1. **Windows**: Right-click the `bbf_backups` folder → Properties → Security → Add your user with full control
2. **Container**: The container automatically sets proper permissions on startup

### Backup Files Not Found

1. **Check directory structure**: Ensure files are in the correct nested directory structure
2. **Check file names**: Ensure backup files match the expected naming convention
3. **Run test script**: Use `./test-volume-mount.sh` to diagnose issues

## Environment Variables

The following environment variables are set in the container:

- `BBF_WINDOWS_BACKUPS=/home/postgres/bbf_backups`
- `BBF_DOCKER_BACKUPS=/var/lib/babelfish/bbf_backups`
- `BBF_HOST_BACKUP_PATH=C:/Users/${USERNAME}/bbf_backups`

## File Structure Example

```
Windows Host:                    Container:
C:\Users\rmosw\bbf_backups\  →  /home/postgres/bbf_backups/
├── northwind\               →  ├── northwind/
│   └── 2024-01-15_1430\    →  │   └── 2024-01-15_1430/
│       ├── northwind.tar   →  │       ├── northwind.tar
│       └── northwind.pgsql →  │       └── northwind.pgsql
└── adventureworks\          →  └── adventureworks/
    └── 2024-01-15_1500\    →      └── 2024-01-15_1500/
        ├── adventureworks.tar →      ├── adventureworks.tar
        └── adventureworks.pgsql →    └── adventureworks.pgsql
```

## Notes

- The Windows path uses forward slashes (`/`) in the Docker Compose configuration
- The `${USERNAME}` variable is automatically expanded by Docker Compose
- Backup files are automatically discovered by the restore script
- The container runs as the `postgres` user with appropriate permissions
