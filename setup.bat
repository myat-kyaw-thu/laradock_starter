@echo off
:: =============================================================
::  LaraDoc Starter — Environment Setup (Windows)
::  Usage: setup.bat [--fresh]
::
::  --fresh   Wipe all volumes and start clean
::
::  What this does:
::    1. Checks Docker is running
::    2. Builds the PHP image
::    3. Starts all containers (MySQL, Redis, Nginx, Mailpit, phpMyAdmin)
::    4. Waits for MySQL to be healthy
::
::  To add a Laravel project after this:
::    add-project.bat <name> <port>
::    e.g. add-project.bat my-app 8080
:: =============================================================

setlocal EnableDelayedExpansion

set FRESH=false
for %%A in (%*) do (
  if "%%A"=="--fresh" set FRESH=true
)

echo.
echo   ==========================================
echo    LaraDoc Starter -- Environment Setup
echo   ==========================================
echo.

:: ── 1. Check Docker ──────────────────────────────────────────
echo [1/4] Checking Docker...

where docker >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo [ERROR] Docker not installed. Get it from https://www.docker.com/products/docker-desktop
  pause & exit /b 1
)

docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo [ERROR] Docker is not running. Start Docker Desktop and try again.
  pause & exit /b 1
)

set DC=docker compose
docker compose version >nul 2>&1
if %ERRORLEVEL% neq 0 (
  set DC=docker-compose
  docker-compose version >nul 2>&1
  if !ERRORLEVEL! neq 0 (
    echo [ERROR] Docker Compose not found.
    pause & exit /b 1
  )
)
echo [OK] Docker is ready.

:: ── 2. Fresh wipe ────────────────────────────────────────────
echo.
if not "%FRESH%"=="true" goto skip_fresh
echo [2/4] Fresh mode -- wiping volumes and containers...
%DC% down -v --remove-orphans
echo [OK] Wiped.
goto after_fresh

:skip_fresh
echo [2/4] Skipping wipe (use --fresh to start clean).

:after_fresh

:: ── 3. Build + Start ─────────────────────────────────────────
echo.
echo [3/4] Building images and starting containers...
echo       (First run pulls/builds images -- may take a few minutes)
echo.
%DC% up -d --build --remove-orphans
if %ERRORLEVEL% neq 0 (
  echo [ERROR] Failed to start containers. Check output above.
  pause & exit /b 1
)
echo [OK] Containers started.

:: ── 4. Wait for MySQL ────────────────────────────────────────
echo.
echo [4/4] Waiting for MySQL to be ready...
set /a WAITED=0

:wait_mysql
%DC% exec mysql mysqladmin ping -h localhost --silent >nul 2>&1
if %ERRORLEVEL% equ 0 goto mysql_ready
if %WAITED% geq 90 goto mysql_timeout
timeout /t 3 /nobreak >nul
set /a WAITED+=3
goto wait_mysql

:mysql_timeout
echo [ERROR] MySQL not ready after 90s. Run: %DC% logs mysql
pause & exit /b 1

:mysql_ready
echo [OK] MySQL is ready.

:: ── Done ─────────────────────────────────────────────────────
echo.
echo   ==========================================
echo    Environment is up and running!
echo   ==========================================
echo.
echo   Next step — add your first project:
echo.
echo     add-project.bat my-app 8080
echo.
echo   Services:
echo     phpMyAdmin  --^>  http://localhost:8081
echo     Mailpit     --^>  http://localhost:8025
echo.
pause
endlocal
