@echo off
title se-pipeline Update
setlocal enabledelayedexpansion

cd /d "%~dp0"

echo ============================================
echo  se-pipeline -- Update
echo ============================================
echo.

REM Check Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker Desktop is not running.
    echo Please start Docker Desktop and re-run this script.
    echo.
    pause
    exit /b 1
)

echo Pulling latest image...
echo.
docker compose pull
if errorlevel 1 (
    echo ERROR: docker compose pull failed.
    pause
    exit /b 1
)
echo.

echo Restarting services with new image...
echo.
docker compose up -d --force-recreate
if errorlevel 1 (
    echo ERROR: docker compose up failed.
    pause
    exit /b 1
)
echo.

echo Waiting for API to be ready...
set API_READY=
for /l %%i in (1,1,20) do (
    if not defined API_READY (
        timeout /t 4 /nobreak >nul
        curl -sf http://localhost:8000/docs >nul 2>&1
        if not errorlevel 1 set API_READY=1
    )
)
if not defined API_READY (
    echo [WARN] API did not respond within 80s. Check: docker compose ps
) else (
    echo [OK] API is ready.
)
echo.

REM ── Update CLI binary from GitHub Releases ───
echo.
echo Updating se-pipeline CLI binary...
echo.

set CLI_URL=https://github.com/drakvai-sudo/se-pipeline-releases/releases/latest/download/se-pipeline-windows.exe
set CLI_DIR=%USERPROFILE%\.local\bin
set CLI_BIN=%CLI_DIR%\se-pipeline.exe

if not exist "%CLI_DIR%" mkdir "%CLI_DIR%"

powershell -NoProfile -Command ^
    "Invoke-WebRequest -Uri '%CLI_URL%' -OutFile '%CLI_BIN%' -UseBasicParsing"
if errorlevel 1 (
    echo [WARN] CLI update failed -- previous binary unchanged.
) else (
    echo [OK] CLI updated: %CLI_BIN%
)
echo.

echo ============================================
echo  Update complete!
echo ============================================
echo.
docker compose ps
echo.
pause
