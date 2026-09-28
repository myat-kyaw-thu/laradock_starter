@echo off
setlocal EnableDelayedExpansion

set PROJECT=%~1
set CLONE_MODE=false
set CLONE_URL=
set EXISTING_MODE=false

if "%PROJECT%"=="" (
  echo [ERROR] Usage: add-project.bat ^<name^> [--clone ^<git-url^>] [--existing]
  pause & exit /b 1
)

if "%~2"=="--clone"    set CLONE_MODE=true & set CLONE_URL=%~3
if "%~2"=="--existing" set EXISTING_MODE=true

set DC=docker compose

set /a REDIS_DB_INDEX=1
for %%F in (docker\frankenphp\conf.d\*.caddyfile) do set /a REDIS_DB_INDEX+=1
set /a VITE_PORT=5173 + REDIS_DB_INDEX - 1

echo.
echo   =============================================
echo    Adding project: %PROJECT%.localhost
echo   =============================================
echo.

%DC% ps --services 2>nul | findstr "frankenphp" >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo [ERROR] Containers not running. Run setup.bat first.
  pause & exit /b 1
)

if exist "src\%PROJECT%\" (
  if not "%CLONE_MODE%"=="true" (
    set EXISTING_MODE=true
    echo [OK] Existing project detected at src\%PROJECT%\
  ) else (
    echo [ERROR] src\%PROJECT%\ already exists. Choose a different name.
    pause & exit /b 1
  )
)

echo [1/7] Creating project...

if "%CLONE_MODE%"=="true" (
  git clone "%CLONE_URL%" "src\%PROJECT%"
  if %ERRORLEVEL% neq 0 ( echo [ERROR] Git clone failed. & pause & exit /b 1 )
  echo [OK] Cloned into src\%PROJECT%
) else if "%EXISTING_MODE%"=="true" (
  if not exist "src\%PROJECT%\" ( echo [ERROR] src\%PROJECT%\ not found. & pause & exit /b 1 )
  echo [OK] Using existing project at src\%PROJECT%\
) else (
  %DC% exec frankenphp composer create-project laravel/laravel %PROJECT%
  if %ERRORLEVEL% neq 0 ( echo [ERROR] Laravel project creation failed. & pause & exit /b 1 )
  echo [OK] Fresh Laravel project created in src\%PROJECT%
)

if not exist "src\%PROJECT%\laradoc.bat" (
  (echo @echo off & echo call "%%~dp0..\..\laradoc.bat" %%*) > "src\%PROJECT%\laradoc.bat"
)
if not exist "src\%PROJECT%\laradoc.ps1" (
  (echo ^& "$PSScriptRoot\..\..\laradoc.ps1" @args) > "src\%PROJECT%\laradoc.ps1"
)

echo.
echo [2/7] Creating Caddyfile site config...
set CONF=docker\frankenphp\conf.d\%PROJECT%.caddyfile
powershell -NoProfile -Command "(Get-Content 'docker\frankenphp\project.caddyfile.template') -replace '__PROJECT_NAME__', '%PROJECT%' | Set-Content '%CONF%'"
echo [OK] Created %CONF%

echo.
echo [3/7] Creating database and dedicated user...
set DB_USER=%PROJECT:-=_%
for /f "usebackq tokens=*" %%P in (`powershell -NoProfile -Command "[Guid]::NewGuid().ToString('N').Substring(0,16)"`) do set DB_PASS=%%P

%DC% exec mysql mysql -u root -prootsecret -e "CREATE DATABASE IF NOT EXISTS \`%PROJECT%\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE USER IF NOT EXISTS '%DB_USER%'@'%%' IDENTIFIED BY '%DB_PASS%'; GRANT ALL PRIVILEGES ON \`%PROJECT%\`.* TO '%DB_USER%'@'%%'; FLUSH PRIVILEGES;"
if %ERRORLEVEL% neq 0 ( echo [WARN] Could not create database/user. ) else ( echo [OK] Database and user '%DB_USER%' created. )

echo.
echo [4/7] Setting up .env...

if "%EXISTING_MODE%"=="true" if exist "src\%PROJECT%\.env" (
  echo [SKIP] Existing .env detected -- skipping .env generation to preserve your settings.
  goto env_done
)

if exist ".env.docker" ( copy ".env.docker" "src\%PROJECT%\.env" >nul ) else ( copy ".env.docker.example" "src\%PROJECT%\.env" >nul )

powershell -NoProfile -Command "(Get-Content 'src\%PROJECT%\.env') -replace 'APP_NAME=.*','APP_NAME=%PROJECT%' -replace 'APP_URL=.*','APP_URL=http://%PROJECT%.localhost' -replace 'DB_DATABASE=.*','DB_DATABASE=%PROJECT%' -replace 'DB_USERNAME=.*','DB_USERNAME=%DB_USER%' -replace 'DB_PASSWORD=.*','DB_PASSWORD=%DB_PASS%' | Set-Content 'src\%PROJECT%\.env'"

findstr /c:"REDIS_DB=" "src\%PROJECT%\.env" >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo.>> "src\%PROJECT%\.env"
  echo REDIS_DB=%REDIS_DB_INDEX%>> "src\%PROJECT%\.env"
  echo REDIS_PREFIX=%PROJECT%_>> "src\%PROJECT%\.env"
  echo CACHE_PREFIX=%PROJECT%_cache>> "src\%PROJECT%\.env"
) else (
  powershell -NoProfile -Command "(Get-Content 'src\%PROJECT%\.env') -replace 'REDIS_DB=.*','REDIS_DB=%REDIS_DB_INDEX%' -replace 'REDIS_PREFIX=.*','REDIS_PREFIX=%PROJECT%_' -replace 'CACHE_PREFIX=.*','CACHE_PREFIX=%PROJECT%_cache' | Set-Content 'src\%PROJECT%\.env'"
)
echo [OK] Created src\%PROJECT%\.env

:env_done

echo.
echo [5/7] Fixing permissions...
%DC% exec --user root frankenphp chown -R laravel:laravel /var/www/html/%PROJECT%/storage /var/www/html/%PROJECT%/bootstrap/cache >nul 2>&1
%DC% exec --user root frankenphp chmod -R 775 /var/www/html/%PROJECT%/storage /var/www/html/%PROJECT%/bootstrap/cache >nul 2>&1
echo [OK] Permissions set.

if not exist "src\%PROJECT%\vendor\" (
  %DC% exec frankenphp sh -c "cd /var/www/html/%PROJECT% && composer install --no-interaction --prefer-dist"
  if %ERRORLEVEL% neq 0 ( echo [WARN] Composer install failed. ) else ( echo [OK] Composer dependencies installed. )
)

echo.
findstr /C:"APP_KEY=base64:" "src\%PROJECT%\.env" >nul 2>&1
if %ERRORLEVEL% neq 0 (
  %DC% exec frankenphp sh -c "cd /var/www/html/%PROJECT% && php artisan key:generate --force"
  echo [OK] App key generated.
) else (
  echo [OK] Existing APP_KEY preserved.
)
%DC% exec frankenphp sh -c "cd /var/www/html/%PROJECT% && php artisan migrate --force"
if %ERRORLEVEL% neq 0 ( echo [WARN] Migrations failed. Check src\%PROJECT%\.env DB settings. ) else ( echo [OK] Migrations complete. )

if not exist "src\%PROJECT%\vite.config.js" (
  copy "docker\vite.config.js" "src\%PROJECT%\vite.config.js" >nul
  powershell -NoProfile -Command "(Get-Content 'src\%PROJECT%\vite.config.js') -replace 'port: 5173','port: %VITE_PORT%' | Set-Content 'src\%PROJECT%\vite.config.js'"
  echo [OK] Vite config copied on port %VITE_PORT%
)

echo.
echo [7/7] Reloading FrankenPHP...
%DC% exec frankenphp frankenphp reload --config /etc/frankenphp/Caddyfile
if %ERRORLEVEL% neq 0 ( echo [WARN] FrankenPHP reload failed. ) else ( echo [OK] FrankenPHP reloaded. )

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
pause
endlocal
