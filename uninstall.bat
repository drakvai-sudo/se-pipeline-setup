@echo off
title se-pipeline Uninstall
setlocal enabledelayedexpansion

cd /d "%~dp0"

echo ============================================
echo  se-pipeline -- Uninstall
echo ============================================
echo.
echo This will stop all services and remove all data volumes.
echo Your .env configuration file will NOT be deleted.
echo.
set /p CONFIRM=Are you sure? Type YES to continue:
if /i not "%CONFIRM%"=="YES" (
    echo Cancelled.
    pause
    exit /b 0
)
echo.

REM Stop and remove containers + volumes
docker info >nul 2>&1
if not errorlevel 1 (
    echo Stopping and removing services...
    docker compose down -v
    echo [OK] Services stopped and data volumes removed.
) else (
    echo [WARN] Docker is not running -- skipping container removal.
)
echo.

REM Remove CLI wrapper
set CLI_WRAPPER=%USERPROFILE%\.local\bin\se-pipeline.bat
if exist "%CLI_WRAPPER%" (
    del /f "%CLI_WRAPPER%"
    echo [OK] CLI wrapper removed from %USERPROFILE%\.local\bin
) else (
    echo [OK] CLI wrapper not found -- nothing to remove.
)
echo.

echo ============================================
echo  Uninstall complete.
echo ============================================
echo.
echo Your .env file has been kept at:
echo   %~dp0.env
echo Delete it manually if you no longer need your configuration.
echo.
pause
