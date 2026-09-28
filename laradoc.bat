@echo off
setlocal EnableDelayedExpansion

set LARADOC_DIR=%~dp0
set LARADOC_DIR=%LARADOC_DIR:~0,-1%

if not exist "%LARADOC_DIR%\docker-compose.yml" (
  echo [ERROR] docker-compose.yml not found in %LARADOC_DIR%
  exit /b 1
)

set DC=docker compose --project-directory "%LARADOC_DIR%"

set PROJECT=
set PROJECT_SOURCE=

set SRC_DIR=%LARADOC_DIR%\src\
echo !CD!\ | findstr /b /i /c:"!SRC_DIR!" >nul 2>&1
if !ERRORLEVEL! equ 0 (
  set REMAINING_PATH=!CD:%SRC_DIR%=!
  for /f "tokens=1 delims=\" %%P in ("!REMAINING_PATH!") do (
    if exist "%LARADOC_DIR%\src\%%P\" (
      set PROJECT=%%P
      set PROJECT_SOURCE=cwd
    )
  )
)

set COMMAND=%~1
if "%COMMAND%"=="" set COMMAND=help

if /i "%COMMAND%"=="artisan"  goto cmd_project
if /i "%COMMAND%"=="a"        set COMMAND=artisan& goto cmd_project
if /i "%COMMAND%"=="composer" goto cmd_project
if /i "%COMMAND%"=="c"        set COMMAND=composer& goto cmd_project
if /i "%COMMAND%"=="php"      goto cmd_project
if /i "%COMMAND%"=="tinker"   goto cmd_tinker
if /i "%COMMAND%"=="ti"       goto cmd_tinker
if /i "%COMMAND%"=="test"     goto cmd_test
if /i "%COMMAND%"=="t"        goto cmd_test
if /i "%COMMAND%"=="shell"    goto cmd_shell
if /i "%COMMAND%"=="sh"       goto cmd_shell
if /i "%COMMAND%"=="mysql"    goto cmd_mysql
if /i "%COMMAND%"=="db"       goto cmd_mysql
if /i "%COMMAND%"=="npm"      goto cmd_project_npm
if /i "%COMMAND%"=="add"      goto cmd_add
if /i "%COMMAND%"=="up"       goto cmd_up
if /i "%COMMAND%"=="down"     goto cmd_down
if /i "%COMMAND%"=="logs"     goto cmd_logs
if /i "%COMMAND%"=="ps"       goto cmd_ps
if /i "%COMMAND%"=="status"   goto cmd_ps
if /i "%COMMAND%"=="build"    goto cmd_build
if /i "%COMMAND%"=="reload"   goto cmd_reload
if /i "%COMMAND%"=="help"     goto cmd_help
if /i "%COMMAND%"=="--help"   goto cmd_help
if /i "%COMMAND%"=="-h"       goto cmd_help

echo [ERROR] Unknown command: %COMMAND%
goto cmd_help

:cmd_project
call :resolve_project_if_needed %2
if not defined PROJECT goto no_project

if /i "%COMMAND%"=="artisan"  set EXEC=php artisan
if /i "%COMMAND%"=="composer" set EXEC=composer
if /i "%COMMAND%"=="php"      set EXEC=php

if "%PROJECT_SOURCE%"=="arg" (
  %DC% exec -w "/var/www/html/%PROJECT%" frankenphp %EXEC% %3 %4 %5 %6 %7 %8 %9
) else (
  %DC% exec -w "/var/www/html/%PROJECT%" frankenphp %EXEC% %2 %3 %4 %5 %6 %7 %8 %9
)
goto :eof

:cmd_tinker
call :resolve_project_if_needed %2
if not defined PROJECT goto no_project
%DC% exec -w "/var/www/html/%PROJECT%" frankenphp php artisan tinker
goto :eof

:cmd_test
call :resolve_project_if_needed %2
if not defined PROJECT goto no_project
if "%PROJECT_SOURCE%"=="arg" (
  %DC% exec -w "/var/www/html/%PROJECT%" frankenphp php artisan test %3 %4 %5 %6 %7 %8 %9
) else (
  %DC% exec -w "/var/www/html/%PROJECT%" frankenphp php artisan test %2 %3 %4 %5 %6 %7 %8 %9
)
goto :eof

:cmd_shell
call :resolve_project_if_needed %2
if not defined PROJECT goto no_project
echo Entering %PROJECT% shell...
%DC% exec -w "/var/www/html/%PROJECT%" frankenphp bash
goto :eof

:cmd_mysql
call :resolve_project_if_needed %2
if not defined PROJECT goto no_project
echo Connecting to MySQL database: %PROJECT%
%DC% exec mysql mysql -u root -prootsecret %PROJECT%
goto :eof

:cmd_project_npm
call :resolve_project_if_needed %2
if not defined PROJECT goto no_project
if "%PROJECT_SOURCE%"=="arg" (
  %DC% exec -w "/var/www/html/%PROJECT%" frankenphp npm %3 %4 %5 %6 %7 %8 %9
) else (
  %DC% exec -w "/var/www/html/%PROJECT%" frankenphp npm %2 %3 %4 %5 %6 %7 %8 %9
)
goto :eof

:cmd_add
call "%LARADOC_DIR%\add-project.bat" %2 %3 %4 %5 %6 %7 %8 %9
goto :eof

:cmd_up
%DC% up -d --remove-orphans %2 %3 %4 %5
echo [OK] Containers started.
echo.
echo   Environment URLs:
echo     Dashboard   --^> http://localhost
echo     phpMyAdmin  --^> http://phpmyadmin.localhost
echo     Mailpit     --^> http://mailpit.localhost
if exist "%LARADOC_DIR%\src\" (
  set HAS_PROJECTS=false
  for /d %%D in ("%LARADOC_DIR%\src\*") do (
    if "!HAS_PROJECTS!"=="false" (
      echo.
      echo   Active Projects:
      set HAS_PROJECTS=true
    )
    echo     %%~nxD --^> http://%%~nxD.localhost
  )
)
echo.
goto :eof

:cmd_down
%DC% --profile "*" down --remove-orphans %2 %3 %4 %5
echo [OK] All containers stopped.
goto :eof

:cmd_logs
%DC% logs -f %2 %3 %4 %5
goto :eof

:cmd_ps
%DC% ps %2 %3 %4 %5
goto :eof

:cmd_build
%DC% build --no-cache %2 %3 %4 %5
echo [OK] Build complete.
goto :eof

:cmd_reload
%DC% exec frankenphp frankenphp reload --config /etc/frankenphp/Caddyfile
echo [OK] FrankenPHP reloaded.
goto :eof

:cmd_help
echo.
echo   LaraDoc CLI -- Run Laravel commands inside Docker
echo.
echo   Usage:
echo     laradoc ^<command^> [project] [arguments...]
echo.
echo   Laravel Commands:
echo     artisan  [args]       Run php artisan
echo     composer [args]       Run composer
echo     php      [args]       Run raw php
echo     tinker                Start Laravel Tinker REPL
echo     test     [args]       Run php artisan test
echo.
echo   Environment:
echo     shell    [project]    Open bash inside project container
echo     mysql    [project]    Open MySQL CLI for project database
echo     npm      [args]       Run npm in project
echo.
echo   Docker:
echo     add      ^<name^>       Add a new Laravel project
echo     up                    Start containers
echo     down                  Stop containers
echo     logs     [service]    Tail container logs
echo     ps                    Show container status
echo     build                 Rebuild FrankenPHP image locally
echo.
echo   Shortcuts:
echo     a = artisan   c = composer   t = test
echo     ti = tinker   sh = shell     db = mysql
echo.
echo   Project is auto-detected from your current directory.
echo.
goto :eof

:resolve_project_if_needed
if defined PROJECT goto :eof

if "%~1"=="" goto auto_detect
if exist "%LARADOC_DIR%\src\%~1\" (
  set PROJECT=%~1
  set PROJECT_SOURCE=arg
  goto :eof
)

:auto_detect
set PROJECT_COUNT=0
set LAST_PROJECT=
for /d %%D in ("%LARADOC_DIR%\src\*") do (
  set /a PROJECT_COUNT+=1
  set LAST_PROJECT=%%~nxD
)

if %PROJECT_COUNT% equ 0 goto no_project
if %PROJECT_COUNT% equ 1 (
  set PROJECT=!LAST_PROJECT!
  set PROJECT_SOURCE=auto
  goto :eof
)

echo.
echo   Multiple projects found. Please specify:
set /a IDX=0
for /d %%D in ("%LARADOC_DIR%\src\*") do (
  set /a IDX+=1
  echo     !IDX!^) %%~nxD
)
echo.
set /p CHOICE="  Choose [1-%PROJECT_COUNT%]: "

set /a IDX=0
for /d %%D in ("%LARADOC_DIR%\src\*") do (
  set /a IDX+=1
  if "!IDX!"=="!CHOICE!" (
    set PROJECT=%%~nxD
    set PROJECT_SOURCE=menu
  )
)

if not defined PROJECT (
  echo [ERROR] Invalid selection.
  exit /b 1
)
goto :eof

:no_project
echo [ERROR] No project found in src\. Add one first:
echo   add-project.bat my-app
exit /b 1
