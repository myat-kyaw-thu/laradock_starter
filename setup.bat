@echo off
:: =============================================================
::  Laravel Docker — First-time setup script (Windows)
::  Usage: setup.bat [--fresh]
::
::  --fresh   Drop existing volumes and start clean
::
::  What this does (automatically):
::    1. Checks Docker is installed and running
::    2. Sets up .env file
::    3. Builds Docker images
::    4. Starts all containers
::    5. Waits for MySQL to be healthy
::    6. Creates a fresh Laravel project if src\ is empty
::    7. Generates app key + runs migrations
:: =============================================================

setlocal EnableDelayedExpansion

:: ── Parse arguments ──────────────────────────────────────────
set FRESH=false
for %%A in (%*) do (
  if "%%A"=="--fresh" set FRESH=true
)

:: ── Banner ───────────────────────────────────────────────────
echo.
echo   ==========================================
echo    Laravel Docker -- Setup Script (Windows)
echo   ==========================================
echo.

:: ── 1. Check Docker ──────────────────────────────────────────
echo [1/7] Checking prerequisites...

where docker >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo [ERROR] Docker is not installed.
  echo         Download Docker Desktop from: https://www.docker.com/products/docker-desktop
  pause & exit /b 1
)

docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo [ERROR] Docker daemon is not running.
  echo         Please start Docker Desktop and run this script again.
  pause & exit /b 1
)

:: Detect docker compose v2 vs v1
set DC=docker compose
docker compose version >nul 2>&1
if %ERRORLEVEL% neq 0 (
  set DC=docker-compose
  docker-compose version >nul 2>&1
  if !ERRORLEVEL! neq 0 (
    echo [ERROR] Docker Compose not found. Install Docker Desktop which includes it.
    pause & exit /b 1
  )
)

echo [OK] Docker and Docker Compose found.

:: ── 2. Copy .env ─────────────────────────────────────────────
echo.
echo [2/7] Setting up environment file...

if not exist "src\.env" (
  if exist ".env.docker" (
    copy ".env.docker" "src\.env" >nul
    echo [OK] Copied .env.docker to src\.env
  ) else if exist ".env.docker.example" (
    copy ".env.docker.example" "src\.env" >nul
    echo [WARN] No .env.docker found -- copied .env.docker.example instead.
    echo [WARN] Open src\.env and replace all 'change_me' values before continuing.
    echo.
    pause
  ) else (
    echo [ERROR] Neither .env.docker nor .env.docker.example found.
    echo         Run this script from the project root.
    pause & exit /b 1
  )
) else (
  echo [SKIP] src\.env already exists. Delete it to reset.
)

:: ── 3. Fresh mode ────────────────────────────────────────────
if "%FRESH%"=="true" (
  echo.
  echo [3/7] Fresh mode -- removing existing volumes...
  %DC% down -v --remove-orphans
  echo [OK] Volumes removed.
) else (
  echo.
  echo [3/7] Skipping volume wipe (use --fresh to wipe and start clean).
)

:: ── 4. Build images ───────────────────────────────────────────
echo.
echo [4/7] Building Docker images (first run may take a few minutes)...
%DC% build
if %ERRORLEVEL% neq 0 (
  echo [ERROR] Image build failed. Check the output above.
  pause & exit /b 1
)
echo [OK] Images built.

:: ── 5. Start containers ───────────────────────────────────────
echo.
echo [5/7] Starting containers...
%DC% up -d
if %ERRORLEVEL% neq 0 (
  echo [ERROR] Failed to start containers.
  pause & exit /b 1
)
echo [OK] Containers started.

:: ── 6. Wait for MySQL ────────────────────────────────────────
echo.
echo [6/7] Waiting for MySQL to be ready...
set /a WAITED=0
:wait_mysql
  %DC% exec mysql mysqladmin ping -h localhost --silent >nul 2>&1
  if %ERRORLEVEL% equ 0 goto mysql_ready
  if %WAITED% geq 60 (
    echo [ERROR] MySQL did not become healthy within 60s.
    echo         Run: %DC% logs mysql
    pause & exit /b 1
  )
  timeout /t 2 /nobreak >nul
  set /a WAITED+=2
  goto wait_mysql
:mysql_ready
echo [OK] MySQL is ready.

:: ── 7. Create or install Laravel ────────────────────────────
echo.
echo [7/7] Setting up Laravel...

if not exist "src\composer.json" (
  echo [INFO] src\ is empty -- creating a fresh Laravel project...
  echo [INFO] This downloads Laravel via Composer, may take a minute...
  echo.
  %DC% run --rm composer create-project laravel/laravel .
  if %ERRORLEVEL% neq 0 (
    echo [ERROR] Laravel project creation failed.
    pause & exit /b 1
  )
  echo [OK] Laravel project created in src\

  :: Re-apply our Docker env over the one Laravel just created
  if exist ".env.docker" (
    copy ".env.docker" "src\.env" >nul
    echo [OK] Re-applied .env.docker to src\.env
  ) else if exist ".env.docker.example" (
    copy ".env.docker.example" "src\.env" >nul
    echo [OK] Re-applied .env.docker.example to src\.env
  )
) else (
  echo [OK] Laravel project found in src\
  echo Installing Composer dependencies...
  %DC% exec php composer install --no-interaction --prefer-dist
  if %ERRORLEVEL% neq 0 (
    echo [ERROR] Composer install failed.
    pause & exit /b 1
  )
  echo [OK] Composer dependencies installed.
)

:: Generate app key if not set
echo Generating application key...
%DC% exec php php artisan key:generate

:: Run migrations
echo Running migrations...
%DC% exec php php artisan migrate --force
if %ERRORLEVEL% neq 0 (
  echo [ERROR] Migrations failed.
  pause & exit /b 1
)
echo [OK] Laravel is ready.

:: ── Done ──────────────────────────────────────────────────────
echo.
echo   ==========================================
echo    Setup complete! Your app is ready.
echo   ==========================================
echo.
echo   Laravel App  --^>  http://localhost:8080
echo   phpMyAdmin   --^>  http://localhost:8081
echo   Mailpit      --^>  http://localhost:8025
echo.
echo   Run "make help" to see all available commands.
echo   (Requires make — install via: winget install GnuWin32.Make)
echo.
pause
endlocal
