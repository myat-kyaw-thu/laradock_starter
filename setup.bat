@echo off
setlocal EnableDelayedExpansion

set FRESH=false
for %%A in (%*) do if "%%A"=="--fresh" set FRESH=true

echo.
echo   ==========================================
echo    LaraDoc Starter -- Environment Setup
echo   ==========================================
echo.

echo [1/4] Checking Docker...
where docker >nul 2>&1
if %ERRORLEVEL% neq 0 ( echo [ERROR] Docker not installed. & pause & exit /b 1 )
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 ( echo [ERROR] Docker is not running. Start Docker Desktop. & pause & exit /b 1 )

set DC=docker compose
docker compose version >nul 2>&1
if %ERRORLEVEL% neq 0 (
  set DC=docker-compose
  docker-compose version >nul 2>&1
  if !ERRORLEVEL! neq 0 ( echo [ERROR] Docker Compose not found. & pause & exit /b 1 )
)
echo [OK] Docker is ready.

echo.
if not "%FRESH%"=="true" goto skip_fresh
echo [2/4] Fresh mode -- wiping volumes and containers...
%DC% down -v --remove-orphans
echo [OK] Wiped.
goto after_fresh
:skip_fresh
echo [2/4] Skipping wipe (use --fresh to start clean).
:after_fresh

echo.
echo [3/4] Pulling pre-built images and starting containers...
for %%C in (laravel_frankenphp laravel_mysql laravel_redis laravel_phpmyadmin laravel_mailpit) do docker rm -f %%C >nul 2>&1
%DC% pull --ignore-buildable-pull-failures >nul 2>&1
%DC% up -d --remove-orphans
if %ERRORLEVEL% neq 0 ( echo [ERROR] Failed to start containers. & pause & exit /b 1 )
echo [OK] Containers started.

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

powershell -NoProfile -Command "$d = '%~dp0'.TrimEnd('\'); $u = [Environment]::GetEnvironmentVariable('Path', 'User'); if ($u -split ';' -notcontains $d) { [Environment]::SetEnvironmentVariable('Path', $u + ';' + $d, 'User'); Write-Host '[OK] Added LaraDoc CLI to User PATH.' }"

echo.
echo   ==========================================
echo    Environment is up and running!
echo   ==========================================
echo.
echo   Next step -- add your first project:
echo     add-project.bat my-app
echo.
echo   Dashboard   --^>  http://localhost
echo   phpMyAdmin  --^>  http://phpmyadmin.localhost
echo   Mailpit     --^>  http://mailpit.localhost  (docker compose --profile extras up -d)
echo.
echo   LaraDoc CLI:
echo     laradoc artisan migrate
echo     laradoc composer install
echo     laradoc shell
echo     laradoc help  (see all commands)
echo.
pause
endlocal
