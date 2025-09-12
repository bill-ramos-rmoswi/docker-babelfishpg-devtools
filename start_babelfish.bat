@echo off
REM start_babelfish.bat - SQL Server-style startup script for Babelfish DevContainer
REM Purpose: Provides familiar SQL Server-like commands for Windows users
REM Usage: start_babelfish.bat [options]
REM
REM This script starts the Babelfish DevContainer and ensures Windows backup
REM directories are properly set up and accessible.

setlocal enabledelayedexpansion

echo ================================================================================
echo Babelfish for PostgreSQL - Windows Startup Script
echo ================================================================================
echo.

REM Check if Docker is running
docker version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running or not installed.
    echo Please start Docker Desktop and try again.
    echo.
    pause
    exit /b 1
)

REM Create Windows backup directory if it doesn't exist
set "BACKUP_DIR=C:\Users\%USERNAME%\bbf_backups"
if not exist "%BACKUP_DIR%" (
    echo Creating Windows backup directory: %BACKUP_DIR%
    mkdir "%BACKUP_DIR%" 2>nul
    if errorlevel 1 (
        echo WARNING: Could not create backup directory at %BACKUP_DIR%
        echo You may need to run as Administrator or check permissions.
    ) else (
        echo ✓ Created backup directory: %BACKUP_DIR%
    )
) else (
    echo ✓ Backup directory exists: %BACKUP_DIR%
)

echo.
echo Starting Babelfish DevContainer...
echo Please wait while the container initializes...

REM Change to the .devcontainer directory
cd /d "%~dp0.devcontainer"

REM Check if .env file exists - required for credentials
if not exist ".env" (
    echo.
    echo ⚠️  CONFIGURATION REQUIRED: .env file not found
    echo.
    echo The .env file contains database credentials and is required to start Babelfish.
    echo Please create .env file in the .devcontainer directory.
    echo.
    echo Option 1 - Copy from template:
    echo   copy .env.example .env
    echo   Edit .env with your preferred credentials
    echo.
    echo Option 2 - Create minimal .env file:
    echo   echo PGUSER=babelfish_admin ^> .env
    echo   echo PGPASSWORD=YourSecurePassword123! ^>^> .env
    echo   echo PGDATABASE=babelfish_db ^>^> .env
    echo   echo ADMIN_USERNAME=babelfish_admin ^>^> .env
    echo   echo ADMIN_PASSWORD=YourSecurePassword123! ^>^> .env
    echo   echo ADMIN_DATABASE=babelfish_db ^>^> .env
    echo.
    echo ⚠️  SECURITY NOTE: Never commit .env files to version control!
    echo.
    pause
    exit /b 1
)

echo ✓ Environment configuration (.env) found
echo.

REM Start the container using docker-compose
docker-compose up -d

if errorlevel 1 (
    echo.
    echo ERROR: Failed to start Babelfish container.
    echo Please check Docker logs for details:
    echo   docker-compose logs babelfish
    echo.
    pause
    exit /b 1
)

echo.
echo Waiting for Babelfish to be ready...

REM Wait for container to be healthy (max 60 seconds)
set /a "timeout=60"
set /a "count=0"

:wait_loop
docker-compose exec -T babelfish pg_isready -h localhost -p 5432 -U babelfish_admin >nul 2>&1
if not errorlevel 1 goto container_ready

set /a "count+=1"
if !count! geq %timeout% (
    echo.
    echo ERROR: Babelfish did not become ready within %timeout% seconds.
    echo Please check the container status:
    echo   docker-compose logs babelfish
    goto show_status
)

echo Waiting... (!count!/%timeout%)
timeout /t 1 /nobreak >nul
goto wait_loop

:container_ready
echo.
echo ================================================================================
echo ✓ Babelfish for PostgreSQL is now running!
echo ================================================================================

:show_status
echo.
echo Connection Information:
echo   SQL Server (TDS) Port: localhost,3341
echo   PostgreSQL Port:        localhost:2345  
echo   SSH Port:              localhost:2223
echo.
echo Default Credentials:
echo   Username: babelfish_admin
echo   Password: secret_password
echo   Database: babelfish_db
echo.
echo Backup Locations:
echo   Windows: %BACKUP_DIR%
echo   WSL:     /mnt/c/Users/%USERNAME%/bbf_backups
echo   Docker:  babelfish-backups (named volume)
echo.
echo Management Commands:
echo   stop_babelfish.bat     - Stop the container
echo   reset_babelfish.bat    - Reset database and volumes
echo.
echo Container Status:
docker-compose ps

echo.
echo SQL Server Management Studio Connection String:
echo Data Source=localhost,3341;Initial Catalog=babelfish_db;User ID=babelfish_admin;Password=secret_password;TrustServerCertificate=true;
echo.
echo ================================================================================
echo Press any key to close this window...
pause >nul