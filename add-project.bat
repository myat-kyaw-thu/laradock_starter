@echo off
:: =============================================================
::  LaraDoc Starter — Add Project (Windows)
::  Usage: add-project.bat <name> [port] [--clone <git-url>]
::
::  Examples:
::    add-project.bat my-app              (auto port from 8080)
::    add-project.bat my-app 8082
::    add-project.bat my-app 8082 --clone https://github.com/you/repo
::
::  What this does:
::    1. Creates src\<name>\ (fresh Laravel or git clone)
::    2. Generates docker\nginx\conf.d\<name>.conf on chosen port
::    3. Creates database <name> in MySQL
::    4. Creates src\<name>\.env with correct DB + URL settings
::    5. Fixes permissions
::    6. Generates app key + runs migrations
::    7. Reloads Nginx
:: =============================================================

setlocal EnableDelayedExpansion

:: ── Arguments ────────────────────────────────────────────────
set PROJECT=%~1
set PORT=%~2
set CLONE_MODE=false
set CLONE_URL=
set EXISTING_MODE=false

if "%PROJECT%"=="" (
  echo.
  echo [ERROR] Project name required.
  echo Usage: add-project.bat ^<name^> [port] [--clone ^<git-url^>] [--existing]
  pause & exit /b 1
)

if "%~3"=="--clone"    set CLONE_MODE=true    & set CLONE_URL=%~4
if "%~3"=="--existing" set EXISTING_MODE=true

set DC=docker compose

:: ── Auto-detect port if not given ────────────────────────────
if "%PORT%"=="" (
  set PORT=8080
  :find_port
  :: Check if port is already used in any existing conf file
  findstr /r /c:"listen !PORT!" "docker\nginx\conf.d\*.conf" >nul 2>&1
  if %ERRORLEVEL% equ 0 (
    set /a PORT+=1
    goto find_port
  )
)

echo.
echo   ==========================================
echo    Adding project: %PROJECT% on port %PORT%
echo   ==========================================
echo.

:: ── Check containers are running ─────────────────────────────
%DC% ps --services 2>nul | findstr "php" >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo [ERROR] Containers not running. Run setup.bat first.
  pause & exit /b 1
)

:: ── Check project doesn't already exist ──────────────────────
if exist "src\%PROJECT%\" (
  echo [ERROR] src\%PROJECT%\ already exists. Choose a different name.
  pause & exit /b 1
)

:: ── 1. Create project ─────────────────────────────────────────
echo [1/7] Creating project...

if "%CLONE_MODE%"=="true" (
  echo [INFO] Cloning %CLONE_URL%...
  git clone "%CLONE_URL%" "src\%PROJECT%"
  if %ERRORLEVEL% neq 0 (
    echo [ERROR] Git clone failed.
    pause & exit /b 1
  )
  echo [OK] Cloned into src\%PROJECT%
) else if "%EXISTING_MODE%"=="true" (
  if not exist "src\%PROJECT%\" (
    echo [ERROR] src\%PROJECT%\ not found. Copy your project there first.
    pause & exit /b 1
  )
  echo [OK] Using existing project at src\%PROJECT%\
) else (
  echo [INFO] Creating fresh Laravel project -- this may take a minute...
  %DC% run --rm -w /var/www/html composer create-project laravel/laravel %PROJECT%
  if %ERRORLEVEL% neq 0 (
    echo [ERROR] Laravel project creation failed.
    pause & exit /b 1
  )
  echo [OK] Fresh Laravel project created in src\%PROJECT%
)

:: ── 2. Nginx config ───────────────────────────────────────────
echo.
echo [2/7] Creating Nginx config (port %PORT%)...

set CONF=docker\nginx\conf.d\%PROJECT%.conf
powershell -NoProfile -Command ^
  "(Get-Content 'docker\nginx\project.conf.template') ^
   -replace '__PROJECT_NAME__', '%PROJECT%' ^
   -replace '__PORT__', '%PORT%' ^
   | Set-Content '%CONF%'"

echo [OK] Created %CONF%

:: ── 3. Database ───────────────────────────────────────────────
echo.
echo [3/7] Creating database '%PROJECT%'...

%DC% exec mysql mysql -u root -prootsecret -e "CREATE DATABASE IF NOT EXISTS \`%PROJECT%\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
if %ERRORLEVEL% neq 0 (
  echo [WARN] Could not create database. Check MySQL root password in docker-compose.yml.
) else (
  echo [OK] Database '%PROJECT%' created.
)

:: ── 4. .env file ──────────────────────────────────────────────
echo.
echo [4/7] Setting up .env...

if exist "src\%PROJECT%\.env" (
  echo [SKIP] src\%PROJECT%\.env already exists.
  goto env_done
)

if exist ".env.docker" (
  copy ".env.docker" "src\%PROJECT%\.env" >nul
) else (
  copy ".env.docker.example" "src\%PROJECT%\.env" >nul
)

:: Patch DB_DATABASE, APP_URL, APP_NAME for this project
powershell -NoProfile -Command ^
  "(Get-Content 'src\%PROJECT%\.env') ^
   -replace 'APP_NAME=.*',  'APP_NAME=%PROJECT%' ^
   -replace 'APP_URL=.*',   'APP_URL=http://localhost:%PORT%' ^
   -replace 'DB_DATABASE=.*','DB_DATABASE=%PROJECT%' ^
   | Set-Content 'src\%PROJECT%\.env'"

echo [OK] Created src\%PROJECT%\.env

:env_done

:: ── 5. Fix permissions ────────────────────────────────────────
echo.
echo [5/7] Fixing permissions...
%DC% exec --user root php chown -R laravel:laravel /var/www/html/%PROJECT%
%DC% exec --user root php chmod -R 775 /var/www/html/%PROJECT%/storage /var/www/html/%PROJECT%/bootstrap/cache
echo [OK] Permissions set.

:: ── 5b. Composer install if vendor/ missing ──────────────────
if not exist "src\%PROJECT%\vendor\" (
  echo Installing Composer dependencies...
  %DC% exec php sh -c "cd /var/www/html/%PROJECT% && composer install --no-interaction --prefer-dist"
  if %ERRORLEVEL% neq 0 (
    echo [WARN] Composer install failed.
  ) else (
    echo [OK] Composer dependencies installed.
  )
)

:: ── 6. App key + migrations ───────────────────────────────────
echo.
echo [6/7] Generating app key and running migrations...
%DC% exec php sh -c "cd /var/www/html/%PROJECT% && php artisan key:generate --force && php artisan migrate --force"
if %ERRORLEVEL% neq 0 (
  echo [WARN] Migrations failed. Check src\%PROJECT%\.env DB settings.
) else (
  echo [OK] App key generated and migrations complete.
)

:: ── 7. Reload Nginx ───────────────────────────────────────────
echo.
echo [7/7] Reloading Nginx...
%DC% exec nginx nginx -s reload
if %ERRORLEVEL% neq 0 (
  echo [WARN] Nginx reload failed. Check config: docker\nginx\conf.d\%PROJECT%.conf
) else (
  echo [OK] Nginx reloaded.
)

:: ── Done ─────────────────────────────────────────────────────
echo.
echo   ==========================================
echo    Project '%PROJECT%' is ready!
echo   ==========================================
echo.
echo   App         --^>  http://localhost:%PORT%
echo   phpMyAdmin  --^>  http://localhost:9090
echo   Database    --^>  %PROJECT%
echo   Files       --^>  src\%PROJECT%\
echo.
echo   Add another project:
echo     add-project.bat ^<name^> [port]
echo.
pause
endlocal
