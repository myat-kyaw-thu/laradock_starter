#!/usr/bin/env pwsh

param(
    [Parameter(Position = 0)]
    [string]$Command = "help",

    [Parameter(Position = 1, ValueFromRemainingArguments)]
    [string[]]$Arguments
)

$ErrorActionPreference = "Stop"

$LaradocDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path "$LaradocDir\docker-compose.yml")) {
    Write-Host "[ERROR] docker-compose.yml not found in $LaradocDir" -ForegroundColor Red
    exit 1
}

$DC = @("docker", "compose", "--project-directory", $LaradocDir)

function Resolve-LaradocProject {
    param([string[]]$CmdArgs)

    $script:Project = $null
    $script:ArgsShift = 0

    $srcDir = Join-Path $LaradocDir "src"
    $cwd = (Get-Location).Path

    if ($cwd.StartsWith("$srcDir$([IO.Path]::DirectorySeparatorChar)") -or
        $cwd.StartsWith("$srcDir/")) {
        $remainder = $cwd.Substring($srcDir.Length + 1)
        $name = ($remainder -split '[/\\]')[0]
        if ($name -and (Test-Path (Join-Path $srcDir $name) -PathType Container)) {
            $script:Project = $name
            return $true
        }
    }

    if ($CmdArgs.Count -gt 0 -and
        (Test-Path (Join-Path $srcDir $CmdArgs[0]) -PathType Container)) {
        $script:Project = $CmdArgs[0]
        $script:ArgsShift = 1
        return $true
    }

    $projects = @()
    if (Test-Path $srcDir) {
        $projects = Get-ChildItem -Path $srcDir -Directory |
            Where-Object { $_.Name -notlike ".*" } |
            Select-Object -ExpandProperty Name
    }

    if ($projects.Count -eq 0) {
        Write-Host "[ERROR] No projects found in src\. Add one first:" -ForegroundColor Red
        Write-Host "  bash add-project.sh my-app" -ForegroundColor Cyan
        return $false
    }

    if ($projects.Count -eq 1) {
        $script:Project = $projects[0]
        return $true
    }

    Write-Host ""
    Write-Host "  Select a project:" -ForegroundColor White
    for ($i = 0; $i -lt $projects.Count; $i++) {
        Write-Host "    $($i + 1)) $($projects[$i])" -ForegroundColor Cyan
    }
    Write-Host ""
    $choice = Read-Host "  Choose [1-$($projects.Count)]"

    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $projects.Count) {
            $script:Project = $projects[$idx]
            return $true
        }
    }

    Write-Host "[ERROR] Invalid selection." -ForegroundColor Red
    return $false
}

function Get-RemainingArgs {
    if ($null -eq $Arguments) { return @() }
    if ($script:ArgsShift -gt 0 -and $Arguments.Count -gt $script:ArgsShift) {
        return $Arguments[$script:ArgsShift..($Arguments.Count - 1)]
    }
    elseif ($script:ArgsShift -gt 0) {
        return @()
    }
    return $Arguments
}

switch ($Command.ToLower()) {
    { $_ -in "artisan", "a" } {
        if (-not (Resolve-LaradocProject $Arguments)) { exit 1 }
        $remaining = Get-RemainingArgs
        & $DC[0] $DC[1..($DC.Count-1)] exec -w "/var/www/html/$Project" frankenphp php artisan @remaining
    }

    { $_ -in "composer", "c" } {
        if (-not (Resolve-LaradocProject $Arguments)) { exit 1 }
        $remaining = Get-RemainingArgs
        & $DC[0] $DC[1..($DC.Count-1)] exec -w "/var/www/html/$Project" frankenphp composer @remaining
    }

    "php" {
        if (-not (Resolve-LaradocProject $Arguments)) { exit 1 }
        $remaining = Get-RemainingArgs
        & $DC[0] $DC[1..($DC.Count-1)] exec -w "/var/www/html/$Project" frankenphp php @remaining
    }

    { $_ -in "tinker", "ti" } {
        if (-not (Resolve-LaradocProject $Arguments)) { exit 1 }
        & $DC[0] $DC[1..($DC.Count-1)] exec -w "/var/www/html/$Project" frankenphp php artisan tinker
    }

    { $_ -in "test", "t" } {
        if (-not (Resolve-LaradocProject $Arguments)) { exit 1 }
        $remaining = Get-RemainingArgs
        & $DC[0] $DC[1..($DC.Count-1)] exec -w "/var/www/html/$Project" frankenphp php artisan test @remaining
    }

    { $_ -in "shell", "sh" } {
        if (-not (Resolve-LaradocProject $Arguments)) { exit 1 }
        Write-Host "Entering $Project shell..." -ForegroundColor Green
        & $DC[0] $DC[1..($DC.Count-1)] exec -w "/var/www/html/$Project" frankenphp bash
    }

    { $_ -in "mysql", "db" } {
        if (-not (Resolve-LaradocProject $Arguments)) { exit 1 }
        Write-Host "Connecting to MySQL database: $Project" -ForegroundColor Green
        & $DC[0] $DC[1..($DC.Count-1)] exec mysql mysql -u root -prootsecret $Project
    }

    "npm" {
        if (-not (Resolve-LaradocProject $Arguments)) { exit 1 }
        $remaining = Get-RemainingArgs
        & $DC[0] $DC[1..($DC.Count-1)] exec -w "/var/www/html/$Project" frankenphp npm @remaining
    }

    "add" {
        & "$LaradocDir\add-project.bat" @Arguments
    }

    "up" {
        & $DC[0] $DC[1..($DC.Count-1)] up -d --remove-orphans @Arguments
        Write-Host "[OK] Containers started." -ForegroundColor Green
        Write-Host ""
        Write-Host "  Environment URLs:" -ForegroundColor White
        Write-Host "    Dashboard   → http://localhost" -ForegroundColor Cyan
        Write-Host "    phpMyAdmin  → http://phpmyadmin.localhost" -ForegroundColor Cyan
        Write-Host "    Mailpit     → http://mailpit.localhost" -ForegroundColor Cyan
        $srcDir = Join-Path $LaradocDir "src"
        if (Test-Path $srcDir) {
            $projects = Get-ChildItem -Path $srcDir -Directory | Where-Object { $_.Name -notlike ".*" }
            if ($projects.Count -gt 0) {
                Write-Host ""
                Write-Host "  Active Projects:" -ForegroundColor White
                foreach ($p in $projects) {
                    Write-Host "    $($p.Name) → http://$($p.Name).localhost" -ForegroundColor Cyan
                }
            }
        }
        Write-Host ""
    }

    "down" {
        & $DC[0] $DC[1..($DC.Count-1)] --profile "*" down --remove-orphans @Arguments
        Write-Host "[OK] All containers stopped." -ForegroundColor Green
    }

    "logs" {
        & $DC[0] $DC[1..($DC.Count-1)] logs -f @Arguments
    }

    { $_ -in "ps", "status" } {
        & $DC[0] $DC[1..($DC.Count-1)] ps @Arguments
    }

    "build" {
        & $DC[0] $DC[1..($DC.Count-1)] build --no-cache @Arguments
        Write-Host "[OK] Build complete." -ForegroundColor Green
    }

    "reload" {
        & $DC[0] $DC[1..($DC.Count-1)] exec frankenphp frankenphp reload --config /etc/frankenphp/Caddyfile
        Write-Host "[OK] FrankenPHP reloaded." -ForegroundColor Green
    }

    { $_ -in "help", "--help", "-h" } {
        Write-Host ""
        Write-Host "  LaraDoc CLI" -ForegroundColor White -NoNewline
        Write-Host " — Run Laravel commands inside Docker"
        Write-Host ""
        Write-Host "  Usage:" -ForegroundColor White
        Write-Host "    laradoc <command> [project] [arguments...]" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Laravel Commands:" -ForegroundColor White
        Write-Host "    artisan  [args]       Run php artisan" -ForegroundColor Green
        Write-Host "    composer [args]       Run composer" -ForegroundColor Green
        Write-Host "    php      [args]       Run raw php" -ForegroundColor Green
        Write-Host "    tinker                Start Laravel Tinker REPL" -ForegroundColor Green
        Write-Host "    test     [args]       Run php artisan test" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Environment:" -ForegroundColor White
        Write-Host "    shell    [project]    Open bash inside project container" -ForegroundColor Green
        Write-Host "    mysql    [project]    Open MySQL CLI for project database" -ForegroundColor Green
        Write-Host "    npm      [args]       Run npm in project" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Docker:" -ForegroundColor White
        Write-Host "    add      <name>       Add a new Laravel project" -ForegroundColor Green
        Write-Host "    up                    Start containers" -ForegroundColor Green
        Write-Host "    down                  Stop containers" -ForegroundColor Green
        Write-Host "    logs     [service]    Tail container logs" -ForegroundColor Green
        Write-Host "    ps                    Show container status" -ForegroundColor Green
        Write-Host "    build                 Rebuild FrankenPHP image locally" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Shortcuts:" -ForegroundColor DarkGray
        Write-Host "    a = artisan   c = composer   t = test" -ForegroundColor DarkGray
        Write-Host "    ti = tinker   sh = shell     db = mysql" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Project is auto-detected from your current directory." -ForegroundColor DarkGray
        Write-Host ""
    }

    default {
        Write-Host "[ERROR] Unknown command: $Command" -ForegroundColor Red
        & $MyInvocation.MyCommand.Path help
        exit 1
    }
}
