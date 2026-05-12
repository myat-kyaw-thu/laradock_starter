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
PORT="${2:-}"
CLONE_MODE=false
CLONE_URL=""
EXISTING_MODE=false

[[ -z "$PROJECT" ]] && error "Project name required.\nUsage: bash add-project.sh <name> [port] [--clone <url>] [--existing]"

shift; shift 2>/dev/null || true
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

# ── Auto-detect port if not given ────────────────────────────
if [[ -z "$PORT" ]]; then
  PORT=8080
  while grep -r "listen ${PORT}" docker/nginx/conf.d/ &>/dev/null 2>&1; do
    PORT=$((PORT + 1))
  done
fi

# ── Banner ───────────────────────────────────────────────────
echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║  Adding project: ${PROJECT} on port ${PORT}"
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
  $DC run --rm -w /var/www/html composer create-project laravel/laravel "${PROJECT}"
  ok "Fresh Laravel project created in src/${PROJECT}/"
fi

# ── 2. Nginx config ──────────────────────────────────────────
step "2/8" "Creating Nginx config (port ${PORT})"

CONF="docker/nginx/conf.d/${PROJECT}.conf"
sed -e "s/__PROJECT_NAME__/${PROJECT}/g" \
    -e "s/__PORT__/${PORT}/g" \
    docker/nginx/project.conf.template > "$CONF"

ok "Created ${CONF}"

# ── 3. Database ───────────────────────────────────────────────
step "3/8" "Creating database '${PROJECT}'"

$DC exec mysql mysql -u root -prootsecret \
  -e "CREATE DATABASE IF NOT EXISTS \`${PROJECT}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" \
  && ok "Database '${PROJECT}' created." \
  || warn "Could not create database. Check MySQL root password."

# ── 4. .env file ─────────────────────────────────────────────
step "4/8" "Setting up .env"

if [[ ! -f "src/${PROJECT}/.env" ]]; then
  if [[ -f ".env.docker" ]]; then
    cp .env.docker "src/${PROJECT}/.env"
  else
    cp .env.docker.example "src/${PROJECT}/.env"
  fi

  # Patch APP_NAME, APP_URL, DB_DATABASE for this project
  sed -i.bak \
    -e "s|^APP_NAME=.*|APP_NAME=${PROJECT}|" \
    -e "s|^APP_URL=.*|APP_URL=http://localhost:${PORT}|" \
    -e "s|^DB_DATABASE=.*|DB_DATABASE=${PROJECT}|" \
    "src/${PROJECT}/.env"
  rm -f "src/${PROJECT}/.env.bak"

  ok "Created src/${PROJECT}/.env"
else
  warn "src/${PROJECT}/.env already exists — skipping."
fi

# ── 5. Permissions ────────────────────────────────────────────
step "5/8" "Fixing permissions"

$DC exec --user root php chown -R laravel:laravel "/var/www/html/${PROJECT}"
$DC exec --user root php chmod -R 775 \
  "/var/www/html/${PROJECT}/storage" \
  "/var/www/html/${PROJECT}/bootstrap/cache"

ok "Permissions set."

# ── 6. Composer install (if vendor/ missing) ─────────────────
step "6/8" "Installing Composer dependencies"

if [[ ! -d "src/${PROJECT}/vendor" ]]; then
  $DC exec php sh -c "cd /var/www/html/${PROJECT} && composer install --no-interaction --prefer-dist"
  ok "Composer dependencies installed."
else
  ok "vendor/ already exists — skipping composer install."
fi

# ── 7. App key + migrations ───────────────────────────────────
step "7/8" "Generating app key and running migrations"

$DC exec php sh -c "cd /var/www/html/${PROJECT} && php artisan key:generate --force"
$DC exec php sh -c "cd /var/www/html/${PROJECT} && php artisan migrate --force" \
  && ok "Migrations complete." \
  || warn "Migrations failed. Check src/${PROJECT}/.env DB settings."

# ── 8. Reload Nginx ───────────────────────────────────────────
step "8/8" "Reloading Nginx"

$DC exec nginx nginx -s reload \
  && ok "Nginx reloaded." \
  || warn "Nginx reload failed. Check: docker/nginx/conf.d/${PROJECT}.conf"

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║  ✔  Project '${PROJECT}' is ready!${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  App         →  ${CYAN}http://localhost:${PORT}${RESET}"
echo -e "  phpMyAdmin  →  ${CYAN}http://localhost:9090${RESET}"
echo -e "  Database    →  ${CYAN}${PROJECT}${RESET}"
echo -e "  Files       →  ${CYAN}src/${PROJECT}/${RESET}"
echo ""
echo -e "  Add another project:"
echo -e "    ${CYAN}bash add-project.sh <name> [port]${RESET}"
echo ""
