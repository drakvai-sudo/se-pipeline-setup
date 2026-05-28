@echo off
title se-pipeline Setup
setlocal enabledelayedexpansion

REM Always run from the directory where setup.bat lives
cd /d "%~dp0"
set SETUP_DIR=%~dp0
if "%SETUP_DIR:~-1%"=="\" set SETUP_DIR=%SETUP_DIR:~0,-1%

echo ============================================
echo  se-pipeline -- Setup
echo ============================================
echo.

REM ── 1. Check Docker ──────────────────────────
docker --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker not found on this machine.
    echo.
    echo Install Docker Desktop from:
    echo   https://www.docker.com/products/docker-desktop/
    echo Then start Docker Desktop and re-run this script.
    echo.
    pause
    exit /b 1
)
echo [OK] Docker found.

docker info >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: Docker Desktop is installed but not running.
    echo.
    echo Please start Docker Desktop, wait until the whale icon
    echo stops animating, then re-run this script.
    echo.
    pause
    exit /b 1
)
echo [OK] Docker Desktop is running.
echo.

REM ── 2. Create .env if it does not exist ──────
if not exist ".env" (
    echo Creating .env from template...
    copy /y ".env.example" ".env" >nul
    echo [OK] .env created.
) else (
    echo [OK] .env already exists -- skipping template copy.
)
echo.

REM ── 3. Pull latest image ─────────────────────
echo Pulling latest se-pipeline image...
echo This may take several minutes on first run.
echo.
docker compose pull
if errorlevel 1 (
    echo.
    echo ERROR: docker compose pull failed.
    echo Check your internet connection and re-run this script.
    echo.
    pause
    exit /b 1
)
echo.

REM ── 4. Start services ────────────────────────
echo Starting services...
echo.
docker compose up -d
if errorlevel 1 (
    echo.
    echo ERROR: docker compose up failed.
    echo Check the error above, then re-run this script.
    echo.
    pause
    exit /b 1
)
echo.

REM ── 5. Wait for API to be ready ──────────────
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
    echo.
    echo [WARN] API did not respond within 80s.
    echo        Services may still be starting. Check: docker compose ps
    echo        You can set your API key later with:
    echo          se-pipeline config set GROQ_API_KEY gsk_...
    echo.
) else (
    echo [OK] API is ready.
    echo.
    echo Service status:
    docker compose ps
    echo.
)

REM ── 6. Configure GROQ API key ────────────────
echo ============================================
echo  Configuration
echo ============================================
echo.
echo You need a free Groq API key to run the pipeline.
echo Get one at: https://console.groq.com
echo.
echo You can also edit .env directly in this folder
echo or run: se-pipeline config set GROQ_API_KEY gsk_...
echo.
set /p GROQ_KEY=Enter your Groq API key (press Enter to skip for now):
if defined GROQ_KEY (
    powershell -Command "(Get-Content '.env') -replace 'GROQ_API_KEY=.*', 'GROQ_API_KEY=%GROQ_KEY%' | Set-Content '.env'"
    echo [OK] Groq API key saved to .env
) else (
    echo [SKIP] No key entered. Set it later with:
    echo   se-pipeline config set GROQ_API_KEY gsk_...
)
echo.

REM ── 7. Install CLI binary ────────────────────
echo ============================================
echo  Installing se-pipeline CLI
echo ============================================
echo.
echo Downloading se-pipeline CLI binary from GitHub Releases...
echo.

set CLI_DIR=%USERPROFILE%\.local\bin
set CLI_BIN=%CLI_DIR%\se-pipeline.exe
set CLI_URL=https://github.com/drakvai-sudo/se-pipeline-releases/releases/latest/download/se-pipeline-windows.exe

if not exist "%CLI_DIR%" mkdir "%CLI_DIR%"

powershell -NoProfile -Command ^
    "Invoke-WebRequest -Uri '%CLI_URL%' -OutFile '%CLI_BIN%' -UseBasicParsing"
if errorlevel 1 (
    echo [WARN] CLI download failed. Check your internet connection.
    echo        Download manually from:
    echo        https://github.com/drakvai-sudo/se-pipeline-releases/releases
    goto :skip_cli
)
echo [OK] CLI installed to %CLI_BIN%

REM -- 7b. Ensure CLI_DIR is on PATH --
echo %PATH% | find /i "%CLI_DIR%" >nul 2>&1
if errorlevel 1 (
    setx PATH "%CLI_DIR%;%PATH%" >nul 2>&1
    echo [OK] %CLI_DIR% added to your PATH.
    echo      Open a new terminal for the change to take effect.
) else (
    echo [OK] %CLI_DIR% is already on PATH.
)
goto :after_cli

:skip_cli
echo [WARN] CLI install skipped. Run setup.bat again to retry.
:after_cli
echo.

REM ── 8. Done ───────────────────────────────────
echo ============================================
echo  Setup complete!
echo ============================================
echo.
echo se-pipeline is now available in every new terminal.
echo.
echo Open a new terminal and run:
echo   se-pipeline --help
echo.
echo Useful commands:
echo   se-pipeline run --help              submit a task
echo   se-pipeline config set KEY value    set an API key
echo   docker compose ps                   check service status
echo   update.bat                          pull and apply updates
echo.
pause
