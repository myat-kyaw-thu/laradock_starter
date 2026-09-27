#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

step()  { echo -e "\n${CYAN}${BOLD}[$1] $2${RESET}"; }
ok()    { echo -e "${GREEN}✔ $1${RESET}"; }
warn()  { echo -e "${YELLOW}⚠ $1${RESET}"; }
error() { echo -e "${RED}✖ $1${RESET}"; exit 1; }

PROJECT="${1:-}"
CLONE_MODE=false
CLONE_URL=""
EXISTING_MODE=false

[[ -z "$PROJECT" ]] && error "Usage: bash add-project.sh <name> [--clone <url>] [--existing]"

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --clone)    CLONE_MODE=true; CLONE_URL="${2:-}"; shift 2 ;;
    --existing) EXISTING_MODE=true; shift ;;
    *) shift ;;
  esac
done

if docker compose version &>/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose &>/dev/null; then
  DC="docker-compose"
else
  error "Docker Compose not found."
fi

REDIS_DB_INDEX=$(ls -1 docker/frankenphp/conf.d/*.caddyfile 2>/dev/null | wc -l || echo 0)
REDIS_DB_INDEX=$((REDIS_DB_INDEX + 1))
VITE_PORT=$((5173 + REDIS_DB_INDEX - 1))

echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║  Adding project: ${PROJECT}.localhost"
echo "  ╚══════════════════════════════════════╝"
echo -e "${RESET}"

$DC ps --services 2>/dev/null | grep -q "frankenphp" || error "Containers not running. Run: bash setup.sh first."

step "1/8" "Setting up project files"

if [[ "$EXISTING_MODE" == true ]] || [[ -d "src/${PROJECT}" && "$CLONE_MODE" == false ]]; then
  [[ -d "src/${PROJECT}" ]] || error "src/${PROJECT}/ not found. Copy your project there first."
  ok "Using existing project at src/${PROJECT}/"
elif [[ "$CLONE_MODE" == true ]]; then
  [[ -d "src/${PROJECT}" ]] && error "src/${PROJECT}/ already exists."
  [[ -z "$CLONE_URL" ]] && error "--clone requires a URL."
  git clone "$CLONE_URL" "src/${PROJECT}"
  ok "Cloned into src/${PROJECT}/"
else
  $DC exec frankenphp composer create-project laravel/laravel "${PROJECT}"
  ok "Fresh Laravel project created in src/${PROJECT}/"
fi

ln -sf "../../laradoc" "src/${PROJECT}/laradoc" 2>/dev/null || true

step "2/8" "Creating Caddyfile site config"

CONF="docker/frankenphp/conf.d/${PROJECT}.caddyfile"
sed -e "s/__PROJECT_NAME__/${PROJECT}/g" docker/frankenphp/project.caddyfile.template > "$CONF"
ok "Created ${CONF}"

step "3/8" "Creating database and dedicated user"

DB_USER=$(echo "${PROJECT}" | tr '-' '_')
DB_PASS=$(openssl rand -hex 12 2>/dev/null || tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 16)

$DC exec mysql mysql -u root -prootsecret \
  -e "CREATE DATABASE IF NOT EXISTS \`${PROJECT}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
      CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
      GRANT ALL PRIVILEGES ON \`${PROJECT}\`.* TO '${DB_USER}'@'%';
      FLUSH PRIVILEGES;" \
  && ok "Database and user '${DB_USER}' created." \
  || warn "Could not create database/user. Check MySQL root password."

step "4/8" "Setting up .env"

if [[ -f "src/${PROJECT}/.env" ]]; then
  ok "Existing .env detected — skipping .env generation to preserve your settings."
else
  [[ -f ".env.docker" ]] && cp .env.docker "src/${PROJECT}/.env" || cp .env.docker.example "src/${PROJECT}/.env"

  sed -i.bak \
    -e "s|^APP_NAME=.*|APP_NAME=${PROJECT}|" \
    -e "s|^APP_URL=.*|APP_URL=http://${PROJECT}.localhost|" \
    -e "s|^DB_DATABASE=.*|DB_DATABASE=${PROJECT}|" \
    -e "s|^DB_USERNAME=.*|DB_USERNAME=${DB_USER}|" \
    -e "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" \
    "src/${PROJECT}/.env"

  if ! grep -q "REDIS_DB=" "src/${PROJECT}/.env"; then
    printf "\nREDIS_DB=%s\nREDIS_PREFIX=%s_\nCACHE_PREFIX=%s_cache\n" \
      "${REDIS_DB_INDEX}" "${PROJECT}" "${PROJECT}" >> "src/${PROJECT}/.env"
  else
    sed -i.bak \
      -e "s|^REDIS_DB=.*|REDIS_DB=${REDIS_DB_INDEX}|" \
      -e "s|^REDIS_PREFIX=.*|REDIS_PREFIX=${PROJECT}_|" \
      -e "s|^CACHE_PREFIX=.*|CACHE_PREFIX=${PROJECT}_cache|" \
      "src/${PROJECT}/.env"
  fi
  rm -f "src/${PROJECT}/.env.bak"
  ok "Created src/${PROJECT}/.env"
fi

step "5/8" "Fixing permissions"

$DC exec --user root frankenphp chown -R laravel:laravel "/var/www/html/${PROJECT}/storage" "/var/www/html/${PROJECT}/bootstrap/cache" || true
$DC exec --user root frankenphp chmod -R 775 "/var/www/html/${PROJECT}/storage" "/var/www/html/${PROJECT}/bootstrap/cache" || true
ok "Permissions set."

step "6/8" "Installing Composer dependencies"

if [[ ! -d "src/${PROJECT}/vendor" ]]; then
  $DC exec frankenphp sh -c "cd /var/www/html/${PROJECT} && composer install --no-interaction --prefer-dist"
  ok "Composer dependencies installed."
else
  ok "vendor/ already exists — skipping."
fi

step "7/8" "Running Laravel setup tasks"

if ! grep -q "^APP_KEY=base64:" "src/${PROJECT}/.env" 2>/dev/null; then
  $DC exec frankenphp sh -c "cd /var/www/html/${PROJECT} && php artisan key:generate --force"
  ok "Application key generated."
else
  ok "Existing APP_KEY preserved."
fi

$DC exec frankenphp sh -c "cd /var/www/html/${PROJECT} && php artisan migrate --force" \
  && ok "Migrations complete." \
  || warn "Migrations failed. Check src/${PROJECT}/.env DB settings."

if [[ ! -f "src/${PROJECT}/vite.config.js" ]]; then
  cp "docker/vite.config.js" "src/${PROJECT}/vite.config.js"
  sed -i.bak -e "s/port: 5173/port: ${VITE_PORT}/g" "src/${PROJECT}/vite.config.js"
  rm -f "src/${PROJECT}/vite.config.js.bak"
  ok "Vite config copied on port ${VITE_PORT}"
fi

step "8/8" "Reloading FrankenPHP"

$DC exec frankenphp frankenphp reload --config /etc/frankenphp/Caddyfile \
  && ok "FrankenPHP reloaded." \
  || warn "FrankenPHP reload failed."

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║  ✔  Project '${PROJECT}' is ready!${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  App         →  ${CYAN}http://${PROJECT}.localhost${RESET}"
echo -e "  phpMyAdmin  →  ${CYAN}http://phpmyadmin.localhost${RESET}"
echo -e "  Mailpit     →  ${CYAN}http://mailpit.localhost${RESET}"
echo -e "  Database    →  ${CYAN}${PROJECT}${RESET}"
echo -e "  Files       →  ${CYAN}src/${PROJECT}/${RESET}"
echo ""
