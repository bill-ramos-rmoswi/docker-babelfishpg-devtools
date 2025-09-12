@echo off
REM reset_babelfish.bat - Complete database and volume reset for Babelfish DevContainer
REM Purpose: Provides SQL Server-like database reset functionality
REM Usage: reset_babelfish.bat
REM
REM WARNING: This script will PERMANENTLY DELETE all database data and backups!
REM Use this when you need to start completely fresh or resolve persistent issues.

setlocal enabledelayedexpansion

echo ================================================================================
echo Babelfish for PostgreSQL - Database Reset Script
echo ================================================================================
echo.
echo ⚠️  WARNING: This will PERMANENTLY DELETE ALL DATA! ⚠️
echo.
echo This script will remove:
echo   • All database data (babelfish-data volume)
echo   • All Docker backup files (babelfish-backups volume)  
echo   • Container and images (will be rebuilt)
echo.
echo The following will NOT be deleted:
echo   • Windows backup files (C:\Users\%USERNAME%\bbf_backups)
echo   • Source code and configuration files
echo.

set /p "confirm=Type 'DELETE' to confirm complete reset: "
if not "!confirm!"=="DELETE" (
    echo.
    echo Reset cancelled. No changes made.
    echo.
    pause
    exit /b 0
)

echo.
echo ================================================================================
echo Performing Complete Reset...
echo ================================================================================

REM Check if Docker is running
docker version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running or not installed.
    echo Please start Docker Desktop and try again.
    echo.
    pause
    exit /b 1
)

REM Change to the .devcontainer directory
cd /d "%~dp0.devcontainer"

echo.
echo Step 1: Stopping and removing containers...
docker-compose down -v --remove-orphans
if errorlevel 1 (
    echo WARNING: Error stopping containers
) else (
    echo ✓ Containers stopped and removed
)

echo.
echo Step 2: Removing Docker volumes...
docker volume rm docker-babelfishpg-devtools_babelfish-data 2>nul
if not errorlevel 1 (
    echo ✓ Database volume removed
) else (
    echo ℹ Database volume not found or already removed
)

docker volume rm docker-babelfishpg-devtools_babelfish-backups 2>nul  
if not errorlevel 1 (
    echo ✓ Backup volume removed
) else (
    echo ℹ Backup volume not found or already removed
)

echo.
echo Step 3: Removing container images...
docker-compose build --no-cache babelfish >nul 2>&1
if errorlevel 1 (
    echo WARNING: Error rebuilding image
) else (
    echo ✓ Container image rebuilt
)

echo.
echo Step 4: Cleaning up Docker system...
docker system prune -f >nul 2>&1
echo ✓ Docker system cleaned

echo.
echo ================================================================================
echo Reset Complete!
echo ================================================================================
echo.
echo What was deleted:
echo   ✓ All database data and configuration
echo   ✓ All Docker backup files
echo   ✓ Container images (rebuilt)
echo.
echo What was preserved:
echo   ✓ Windows backup files: C:\Users\%USERNAME%\bbf_backups
echo   ✓ Source code and project files
echo   ✓ Docker Compose configuration
echo.
echo Next steps:
echo   1. Run: start_babelfish.bat
echo   2. Wait for initialization (may take 30-60 minutes on first run)
echo   3. Test connection with SQL Server Management Studio
echo.
echo If you have backup files in Windows directory, you can restore them
echo after the container starts using the restore_babelfish.sh script.
echo.
echo ================================================================================
echo Press any key to close this window...
pause >nul