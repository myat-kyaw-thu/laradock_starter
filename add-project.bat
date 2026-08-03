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
set CLONE_MODE=false
set CLONE_URL=
set EXISTING_MODE=false

if "%PROJECT%"=="" (
  echo.
  echo [ERROR] Project name required.
  echo Usage: add-project.bat ^<name^> [--clone ^<git-url^>] [--existing]
  pause & exit /b 1
)

if "%~2"=="--clone"    set CLONE_MODE=true    & set CLONE_URL=%~3
if "%~2"=="--existing" set EXISTING_MODE=true

set DC=docker compose

:: ── Dynamic Redis Database Index and Vite Ports ─────────────
set /a REDIS_DB_INDEX=1
for %%F in (docker\nginx\conf.d\*.conf) do (
  set /a REDIS_DB_INDEX+=1
)
set /a VITE_PORT=5173 + REDIS_DB_INDEX - 1

echo.
echo   =============================================
echo    Adding project: %PROJECT%.localhost
echo   =============================================
echo.

:: ── Check containers are running ─────────────────────────────
%DC% ps --services 2>nul | findstr "php" >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo [ERROR] Containers not running. Run setup.bat first.
  pause & exit /b 1
)

:: ── Check project doesn't already exist ──────────────────────
if exist "src\%PROJECT%\" (
  if not "%EXISTING_MODE%"=="true" (
    echo [ERROR] src\%PROJECT%\ already exists. Choose a different name.
    pause & exit /b 1
  )
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
  %DC% exec php composer create-project laravel/laravel %PROJECT%
  if %ERRORLEVEL% neq 0 (
    echo [ERROR] Laravel project creation failed.
    pause & exit /b 1
  )
  echo [OK] Fresh Laravel project created in src\%PROJECT%
)

:: ── 2. Nginx config ───────────────────────────────────────────
echo.
echo [2/7] Creating Nginx config...

set CONF=docker\nginx\conf.d\%PROJECT%.conf
powershell -NoProfile -Command ^
  "(Get-Content 'docker\nginx\project.conf.template') ^
   -replace '__PROJECT_NAME__', '%PROJECT%' ^
   | Set-Content '%CONF%'"

echo [OK] Created %CONF%

:: ── 3. Database ───────────────────────────────────────────────
echo.
echo [3/7] Creating database and dedicated user (WET isolation)...

:: Clean project name for database user (convert hyphens to underscores)
set DB_USER=%PROJECT:-=_%
for /f "usebackq tokens=*" %%P in (`powershell -NoProfile -Command "[Guid]::NewGuid().ToString('N').Substring(0,16)"`) do set DB_PASS=%%P

%DC% exec mysql mysql -u root -prootsecret -e "CREATE DATABASE IF NOT EXISTS \`%PROJECT%\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE USER IF NOT EXISTS '%DB_USER%'@'%%' IDENTIFIED BY '%DB_PASS%'; GRANT ALL PRIVILEGES ON \`%PROJECT%\`.* TO '%DB_USER%'@'%%'; FLUSH PRIVILEGES;"
if %ERRORLEVEL% neq 0 (
  echo [WARN] Could not create database/user. Check MySQL root password.
) else (
  echo [OK] Database and isolated user '%DB_USER%' created.
)

:: ── 4. .env file ──────────────────────────────────────────────
echo.
echo [4/7] Setting up .env...

if exist "src\%PROJECT%\.env" (
  echo [SKIP] src\%PROJECT%\.env already exists -- skipping overwrite.
  goto env_done
)

if exist ".env.docker" (
  copy ".env.docker" "src\%PROJECT%\.env" >nul
) else (
  copy ".env.docker.example" "src\%PROJECT%\.env" >nul
)

:: Patch APP_NAME, APP_URL, DB_DATABASE, DB_USERNAME, DB_PASSWORD for this project
powershell -NoProfile -Command ^
  "(Get-Content 'src\%PROJECT%\.env') ^
   -replace 'APP_NAME=.*',  'APP_NAME=%PROJECT%' ^
   -replace 'APP_URL=.*',   'APP_URL=http://%PROJECT%.localhost' ^
   -replace 'DB_DATABASE=.*','DB_DATABASE=%PROJECT%' ^
   -replace 'DB_USERNAME=.*','DB_USERNAME=%DB_USER%' ^
   -replace 'DB_PASSWORD=.*','DB_PASSWORD=%DB_PASS%' ^
   | Set-Content 'src\%PROJECT%\.env'"

:: Append Redis / Cache isolation parameters
findstr /c:"REDIS_DB=" "src\%PROJECT%\.env" >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo. >> "src\%PROJECT%\.env"
  echo # Isolation Settings >> "src\%PROJECT%\.env"
  echo REDIS_DB=%REDIS_DB_INDEX% >> "src\%PROJECT%\.env"
  echo REDIS_PREFIX=%PROJECT%_ >> "src\%PROJECT%\.env"
  echo CACHE_PREFIX=%PROJECT%_cache >> "src\%PROJECT%\.env"
) else (
  powershell -NoProfile -Command ^
    "(Get-Content 'src\%PROJECT%\.env') ^
     -replace 'REDIS_DB=.*', 'REDIS_DB=%REDIS_DB_INDEX%' ^
     -replace 'REDIS_PREFIX=.*', 'REDIS_PREFIX=%PROJECT%_' ^
     -replace 'CACHE_PREFIX=.*', 'CACHE_PREFIX=%PROJECT%_cache' ^
     | Set-Content 'src\%PROJECT%\.env'"
)

echo [OK] Created src\%PROJECT%\.env with isolated parameters.

:env_done

echo.
echo [5/7] Fixing permissions...
%DC% exec --user root php chown -R laravel:laravel /var/www/html/%PROJECT%/storage /var/www/html/%PROJECT%/bootstrap/cache >nul 2>&1
%DC% exec --user root php chmod -R 775 /var/www/html/%PROJECT%/storage /var/www/html/%PROJECT%/bootstrap/cache >nul 2>&1
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

:: ── 6. App key + migrations + Vite Config ─────────────────────
echo.
echo [6/7] Generating app key and running migrations...
%DC% exec php sh -c "cd /var/www/html/%PROJECT% && php artisan key:generate --force && php artisan migrate --force"
if %ERRORLEVEL% neq 0 (
  echo [WARN] Migrations failed. Check src\%PROJECT%\.env DB settings.
) else (
  echo [OK] App key generated and migrations complete.
)

:: Copy dynamic Docker-ready Vite config and assign specific port
if not exist "src\%PROJECT%\vite.config.js" (
  copy "docker\vite.config.js" "src\%PROJECT%\vite.config.js" >nul
  powershell -NoProfile -Command ^
    "(Get-Content 'src\%PROJECT%\vite.config.js') ^
     -replace 'port: 5173', 'port: %VITE_PORT%' ^
     | Set-Content 'src\%PROJECT%\vite.config.js'"
  echo [OK] Copied and configured project vite.config.js on port %VITE_PORT%
)

:: ── 7. Reload Nginx ───────────────────────────────────────────
echo.
echo [7/7] Reloading Nginx...
%DC% exec nginx nginx -s reload
if %ERRORLEVEL% neq 0 (
  echo [WARN] Nginx reload failed.
) else (
  echo [OK] Nginx reloaded.
)

:: ── Done ─────────────────────────────────────────────────────
echo.
echo   =============================================
echo    Project '%PROJECT%' is ready!
echo   =============================================
echo.
echo   App         --^>  http://%PROJECT%.localhost
echo   phpMyAdmin  --^>  http://phpmyadmin.localhost
echo   Mailpit     --^>  http://mailpit.localhost
echo   Database    --^>  %PROJECT%
echo   Files       --^>  src\%PROJECT%\
echo.
echo   Add another project:
echo     add-project.bat ^<name^>
echo.
pause
endlocal
