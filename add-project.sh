#!/usr/bin/env bash
# =============================================================
#  LaraDoc Starter — Add Project (Mac / Linux)
#  Usage: bash add-project.sh <name> [port] [--clone <url>] [--existing]
#
#  Examples:
#    bash add-project.sh my-app
#    bash add-project.sh my-app 8080
#    bash add-project.sh my-app 8080 --clone https://github.com/you/repo
#    bash add-project.sh my-app 8080 --existing
#
#  What this does:
#    1. Creates src/<name>/ (fresh Laravel, git clone, or existing)
#    2. Generates docker/nginx/conf.d/<name>.conf on chosen port
#    3. Creates database <name> in MySQL
#    4. Creates src/<name>/.env with correct DB + URL settings
#    5. Fixes permissions
#    6. Runs composer install (if needed)
#    7. Generates app key + runs migrations
#    8. Reloads Nginx
# =============================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

step()  { echo -e "\n${CYAN}${BOLD}[$1] $2${RESET}"; }
ok()    { echo -e "${GREEN}✔ $1${RESET}"; }
warn()  { echo -e "${YELLOW}⚠ $1${RESET}"; }
error() { echo -e "${RED}✖ $1${RESET}"; exit 1; }

# ── Parse arguments ──────────────────────────────────────────
PROJECT="${1:-}"
CLONE_MODE=false
CLONE_URL=""
EXISTING_MODE=false

[[ -z "$PROJECT" ]] && error "Project name required.\nUsage: bash add-project.sh <name> [--clone <url>] [--existing]"

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --clone)    CLONE_MODE=true;    CLONE_URL="${2:-}"; shift 2 ;;
    --existing) EXISTING_MODE=true; shift ;;
    *) shift ;;
  esac
done

# ── Docker Compose command ────────────────────────────────────
if docker compose version &>/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose &>/dev/null; then
  DC="docker-compose"
else
  error "Docker Compose not found."
fi

# ── Generate dynamic project subdomains and Redis databases ──
# Count existing conf.d configurations to assign a unique Redis Database index
REDIS_DB_INDEX=$(ls -1 docker/nginx/conf.d/*.conf 2>/dev/null | wc -l || echo 0)
REDIS_DB_INDEX=$((REDIS_DB_INDEX + 1))
VITE_PORT=$((5173 + REDIS_DB_INDEX - 1))

# ── Banner ───────────────────────────────────────────────────
echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║  Adding project: ${PROJECT}.localhost"
echo "  ╚══════════════════════════════════════╝"
echo -e "${RESET}"

# ── Check containers are running ─────────────────────────────
$DC ps --services 2>/dev/null | grep -q "php" || error "Containers not running. Run: bash setup.sh first."

# ── 1. Create project ────────────────────────────────────────
step "1/8" "Setting up project files"

if [[ "$EXISTING_MODE" == true ]]; then
  [[ -d "src/${PROJECT}" ]] || error "src/${PROJECT}/ not found. Copy your project there first."
  ok "Using existing project at src/${PROJECT}/"

elif [[ "$CLONE_MODE" == true ]]; then
  [[ -d "src/${PROJECT}" ]] && error "src/${PROJECT}/ already exists."
  [[ -z "$CLONE_URL" ]] && error "--clone requires a URL."
  echo "  Cloning ${CLONE_URL}..."
  git clone "$CLONE_URL" "src/${PROJECT}"
  ok "Cloned into src/${PROJECT}/"

else
  [[ -d "src/${PROJECT}" ]] && error "src/${PROJECT}/ already exists. Use --existing or choose a different name."
  echo "  Creating fresh Laravel project — this may take a minute..."
  $DC exec php composer create-project laravel/laravel "${PROJECT}"
  ok "Fresh Laravel project created in src/${PROJECT}/"
fi

# ── 2. Nginx config ──────────────────────────────────────────
step "2/8" "Creating Nginx config"

CONF="docker/nginx/conf.d/${PROJECT}.conf"
sed -e "s/__PROJECT_NAME__/${PROJECT}/g" \
    docker/nginx/project.conf.template > "$CONF"

ok "Created ${CONF}"

# ── 3. Database ───────────────────────────────────────────────
step "3/8" "Creating database and dedicated user (WET isolation)"

# Clean project name for database user (convert hyphens to underscores)
DB_USER=$(echo "${PROJECT}" | tr '-' '_')
DB_PASS=$(openssl rand -hex 12 2>/dev/null || tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 16)

$DC exec mysql mysql -u root -prootsecret \
  -e "CREATE DATABASE IF NOT EXISTS \`${PROJECT}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
      CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
      GRANT ALL PRIVILEGES ON \`${PROJECT}\`.* TO '${DB_USER}'@'%';
      FLUSH PRIVILEGES;" \
  && ok "Database and isolated user '${DB_USER}' created successfully." \
  || warn "Could not create database/user. Check MySQL root password."

# ── 4. .env file ─────────────────────────────────────────────
step "4/8" "Setting up .env"

if [[ ! -f "src/${PROJECT}/.env" ]]; then
  if [[ -f ".env.docker" ]]; then
    cp .env.docker "src/${PROJECT}/.env"
  else
    cp .env.docker.example "src/${PROJECT}/.env"
  fi

  # Patch APP_NAME, APP_URL, DB credentials
  sed -i.bak \
    -e "s|^APP_NAME=.*|APP_NAME=${PROJECT}|" \
    -e "s|^APP_URL=.*|APP_URL=http://${PROJECT}.localhost|" \
    -e "s|^DB_DATABASE=.*|DB_DATABASE=${PROJECT}|" \
    -e "s|^DB_USERNAME=.*|DB_USERNAME=${DB_USER}|" \
    -e "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" \
    "src/${PROJECT}/.env"

  # Append Redis / Cache isolation parameters
  if ! grep -q "REDIS_DB=" "src/${PROJECT}/.env"; then
    echo "" >> "src/${PROJECT}/.env"
    echo "# Isolation Settings" >> "src/${PROJECT}/.env"
    echo "REDIS_DB=${REDIS_DB_INDEX}" >> "src/${PROJECT}/.env"
    echo "REDIS_PREFIX=${PROJECT}_" >> "src/${PROJECT}/.env"
    echo "CACHE_PREFIX=${PROJECT}_cache" >> "src/${PROJECT}/.env"
  else
    sed -i.bak \
      -e "s|^REDIS_DB=.*|REDIS_DB=${REDIS_DB_INDEX}|" \
      -e "s|^REDIS_PREFIX=.*|REDIS_PREFIX=${PROJECT}_|" \
      -e "s|^CACHE_PREFIX=.*|CACHE_PREFIX=${PROJECT}_cache|" \
      "src/${PROJECT}/.env"
  fi
  rm -f "src/${PROJECT}/.env.bak"

  ok "Created src/${PROJECT}/.env with isolated parameters."
else
  # Database and username might have changed if created on another setup, warn developer
  warn "src/${PROJECT}/.env already exists — skipping overwrite."
fi

# ── 5. Permissions ────────────────────────────────────────────
step "5/8" "Fixing permissions"

$DC exec --user root php chown -R laravel:laravel "/var/www/html/${PROJECT}/storage" "/var/www/html/${PROJECT}/bootstrap/cache" || true
$DC exec --user root php chmod -R 775 \
  "/var/www/html/${PROJECT}/storage" \
  "/var/www/html/${PROJECT}/bootstrap/cache" || true

ok "Permissions set."

# ── 6. Composer install (if vendor/ missing) ─────────────────
step "6/8" "Installing Composer dependencies"

if [[ ! -d "src/${PROJECT}/vendor" ]]; then
  $DC exec php sh -c "cd /var/www/html/${PROJECT} && composer install --no-interaction --prefer-dist"
  ok "Composer dependencies installed."
else
  ok "vendor/ already exists — skipping composer install."
fi

# ── 7. App key + migrations + Vite Config ─────────────────────
step "7/8" "Running Laravel setup tasks"

$DC exec php sh -c "cd /var/www/html/${PROJECT} && php artisan key:generate --force"
$DC exec php sh -c "cd /var/www/html/${PROJECT} && php artisan migrate --force" \
  && ok "Migrations complete." \
  || warn "Migrations failed. Check src/${PROJECT}/.env DB settings."

# Copy dynamic Docker-ready Vite config and assign specific port
if [[ ! -f "src/${PROJECT}/vite.config.js" ]]; then
  cp "docker/vite.config.js" "src/${PROJECT}/vite.config.js"
  sed -i.bak -e "s/port: 5173/port: ${VITE_PORT}/g" "src/${PROJECT}/vite.config.js"
  rm -f "src/${PROJECT}/vite.config.js.bak"
  ok "Copied and configured project vite.config.js on port ${VITE_PORT}"
fi

# ── 8. Reload Nginx ───────────────────────────────────────────
step "8/8" "Reloading Nginx"

$DC exec nginx nginx -s reload \
  && ok "Nginx reloaded." \
  || warn "Nginx reload failed."

# ── Done ─────────────────────────────────────────────────────
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
echo -e "  Add another project:"
echo -e "    ${CYAN}bash add-project.sh <name>${RESET}"
echo ""
