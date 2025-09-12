@echo off
REM stop_babelfish.bat - SQL Server-style shutdown script for Babelfish DevContainer
REM Purpose: Provides familiar SQL Server-like commands for Windows users
REM Usage: stop_babelfish.bat
REM
REM This script gracefully stops the Babelfish DevContainer while preserving
REM all data in Docker volumes and Windows backup directories.

setlocal enabledelayedexpansion

echo ================================================================================
echo Babelfish for PostgreSQL - Windows Shutdown Script  
echo ================================================================================
echo.

REM Check if Docker is running
docker version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running or not installed.
    echo Cannot stop container - Docker is not available.
    echo.
    pause
    exit /b 1
)

echo Stopping Babelfish DevContainer...

REM Change to the .devcontainer directory
cd /d "%~dp0.devcontainer"

REM Check if container is running
docker-compose ps -q babelfish >nul 2>&1
if errorlevel 1 (
    echo Container is not running or does not exist.
    goto show_status
)

REM Graceful shutdown
echo Performing graceful shutdown of PostgreSQL...
docker-compose exec babelfish su - postgres -c "pg_ctl -D /var/lib/babelfish/data stop -m fast" 2>nul

echo Stopping container...
docker-compose down

if errorlevel 1 (
    echo.
    echo WARNING: Error occurred during shutdown.
    echo Container may still be running. Check status manually:
    echo   docker-compose ps
) else (
    echo.
    echo ✓ Babelfish container stopped successfully.
)

:show_status
echo.
echo ================================================================================
echo Container Status:
echo ================================================================================
docker-compose ps

echo.
echo Data Preservation:
echo   ✓ Database data preserved in Docker volume: babelfish-data
echo   ✓ Backup files preserved in Docker volume: babelfish-backups  
echo   ✓ Windows backups preserved at: C:\Users\%USERNAME%\bbf_backups
echo.
echo To restart Babelfish:
echo   start_babelfish.bat
echo.
echo To completely reset (WARNING - deletes all data):
echo   reset_babelfish.bat
echo.
echo ================================================================================
echo Press any key to close this window...
pause >nul