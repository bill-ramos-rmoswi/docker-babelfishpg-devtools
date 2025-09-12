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
echo Step 1: Forcefully stopping all Babelfish containers...

REM First try docker-compose down
docker-compose down -v --remove-orphans >nul 2>&1

REM Find and forcefully stop ALL babelfish containers regardless of how they were started
echo Detecting running babelfish containers...
for /f "tokens=1,2" %%i in ('docker ps --format "table {{.ID}} {{.Names}}" ^| findstr "babelfish"') do (
    echo Found running container: %%j (%%i)
    echo Forcefully stopping container: %%j
    docker stop %%i >nul 2>&1
    if not errorlevel 1 (
        echo ✓ Container stopped: %%j
    ) else (
        echo ⚠ Could not stop container: %%j - trying kill
        docker kill %%i >nul 2>&1
    )
)

REM Remove all babelfish containers (running and stopped)
echo Removing all babelfish containers...
for /f "tokens=1,2" %%i in ('docker ps -a --format "table {{.ID}} {{.Names}}" ^| findstr "babelfish"') do (
    echo Removing container: %%j (%%i)
    docker rm -f %%i >nul 2>&1
    if not errorlevel 1 (
        echo ✓ Container removed: %%j
    ) else (
        echo ⚠ Could not remove container: %%j
    )
)

REM Clean up any remaining stopped containers
docker container prune -f >nul 2>&1

echo.
echo Step 2: Detecting and removing Docker volumes...

REM Check if any babelfish volumes exist
docker volume ls | findstr "babelfish" >nul 2>&1
if errorlevel 1 (
    echo ℹ No babelfish volumes found - nothing to remove
    goto step3
)

REM Dynamically detect babelfish volume names  
echo Detecting babelfish volumes...
docker volume ls | findstr "babelfish"
echo.

REM Verify no containers are using these volumes
echo Verifying no containers are using babelfish volumes...
docker ps -a --format "table {{.ID}} {{.Names}}" | findstr "babelfish" >nul 2>&1
if not errorlevel 1 (
    echo ⚠ ERROR: Babelfish containers are still running/stopped!
    echo The following containers may be using the volumes:
    docker ps -a --format "table {{.ID}} {{.Names}}" | findstr "babelfish"
    echo.
    echo Volume deletion will likely fail. Please manually remove containers first:
    for /f "tokens=1" %%c in ('docker ps -a --format "{{.ID}}" ^| findstr "babelfish"') do (
        echo   docker rm -f %%c
    )
    echo.
    echo Attempting volume deletion anyway...
) else (
    echo ✓ No babelfish containers found - volumes should be deletable
)
echo.

for /f "tokens=2" %%i in ('docker volume ls ^| findstr "babelfish-data"') do (
    set "DATA_VOLUME=%%i"
    echo Found data volume: %%i
    docker volume rm -f "%%i" >nul 2>&1
    if not errorlevel 1 (
        echo ✓ Database volume removed: %%i
    ) else (
        echo ⚠ Could not remove database volume: %%i
    )
)

for /f "tokens=2" %%i in ('docker volume ls ^| findstr "babelfish-backups"') do (
    set "BACKUP_VOLUME=%%i"
    echo Found backup volume: %%i
    docker volume rm -f "%%i" >nul 2>&1
    if not errorlevel 1 (
        echo ✓ Backup volume removed: %%i
    ) else (
        echo ⚠ Could not remove backup volume: %%i
    )
)

REM Check if any volumes were found
docker volume ls | findstr "babelfish" >nul 2>&1
if errorlevel 1 (
    echo ✓ All babelfish volumes successfully removed
) else (
    echo ⚠ Some babelfish volumes may still exist - manual cleanup may be needed:
    docker volume ls | findstr "babelfish"
    echo   Try running: docker volume prune -f
)

:step3
echo.
echo Step 3: Removing container images...

REM Remove babelfish images directly (safer than rebuild)
echo Detecting babelfish images...
docker images --format "table {{.ID}} {{.Repository}}" | findstr "babelfish" >nul 2>&1
if errorlevel 1 (
    echo ℹ No babelfish images found to remove
) else (
    echo Found babelfish images:
    docker images --format "table {{.ID}} {{.Repository}}" | findstr "babelfish"
    echo.
    
    echo Removing babelfish images...
    for /f "tokens=1" %%i in ('docker images --format "{{.ID}}" ^| findstr -v "IMAGE"') do (
        docker image inspect %%i --format "{{.RepoTags}}" 2>nul | findstr "babelfish" >nul 2>&1
        if not errorlevel 1 (
            echo Removing image: %%i
            docker rmi -f %%i >nul 2>&1
            if not errorlevel 1 (
                echo ✓ Image removed: %%i
            ) else (
                echo ⚠ Could not remove image: %%i
            )
        )
    )
)

echo.
echo Building fresh image...
echo This may take several minutes - please be patient...

REM Use timeout for build command (Windows timeout command)
timeout 5 >nul
docker-compose build --no-cache babelfish
if errorlevel 1 (
    echo ⚠ WARNING: Image rebuild failed or was interrupted
    echo You may need to rebuild manually later with: docker-compose build --no-cache
) else (
    echo ✓ Fresh container image built successfully
)

echo.
echo Step 4: Cleaning up Docker system...
docker system prune -f >nul 2>&1
echo ✓ Docker system cleaned

echo.
echo ================================================================================
echo Reset Complete - Final Status Report
echo ================================================================================
echo.

REM Final verification of cleanup
echo Verifying cleanup status...
echo.

echo Containers Status:
docker ps -a --format "table {{.ID}} {{.Names}}" | findstr "babelfish" >nul 2>&1
if errorlevel 1 (
    echo   ✓ No babelfish containers found
) else (
    echo   ⚠ Some babelfish containers still exist:
    docker ps -a --format "table {{.ID}} {{.Names}}" | findstr "babelfish"
)

echo.
echo Volumes Status:
docker volume ls | findstr "babelfish" >nul 2>&1
if errorlevel 1 (
    echo   ✓ No babelfish volumes found
) else (
    echo   ⚠ Some babelfish volumes still exist:
    docker volume ls | findstr "babelfish"
)

echo.
echo Windows Backup Directory:
if exist "C:\Users\%USERNAME%\bbf_backups" (
    echo   ✓ Windows backups preserved at: C:\Users\%USERNAME%\bbf_backups
) else (
    echo   ℹ Windows backup directory not found (will be created when needed)
)

echo.
echo ================================================================================
echo Summary of Changes
echo ================================================================================
echo.
echo What was reset:
echo   ✓ All babelfish containers stopped and removed
echo   ✓ All babelfish Docker volumes deleted
echo   ✓ All babelfish images removed and rebuilt
echo   ✓ Docker system cleaned up
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