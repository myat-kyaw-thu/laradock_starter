#!/usr/bin/env bash
# =============================================================
#  Laravel Docker — First-time setup script (Mac / Linux)
#  Usage: bash setup.sh [--fresh]
#
#  --fresh   Drop existing volumes and start clean
#
#  What this does (automatically):
#    1. Checks Docker is installed and running
#    2. Sets up .env file
#    3. Builds Docker images
#    4. Starts all containers
#    5. Waits for MySQL to be healthy
#    6. Creates a fresh Laravel project if src/ is empty
#    7. Generates app key + runs migrations
# =============================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

FRESH=false
for arg in "$@"; do
  [[ "$arg" == "--fresh" ]] && FRESH=true
done

# ── Helpers ──────────────────────────────────────────────────
step()  { echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"; }
ok()    { echo -e "${GREEN}✔ $1${RESET}"; }
warn()  { echo -e "${YELLOW}⚠ $1${RESET}"; }
error() { echo -e "${RED}✖ $1${RESET}"; exit 1; }

# ── Banner ───────────────────────────────────────────────────
echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║   Laravel Docker — Setup Script      ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${RESET}"

# ── 1. Check prerequisites ───────────────────────────────────
step "Checking prerequisites"

if ! command -v docker &>/dev/null; then
  error "Docker is not installed. Download it from https://www.docker.com/products/docker-desktop"
fi
ok "Docker found: $(docker --version)"

# Support both Docker Compose v2 (plugin) and v1 (standalone)
if docker compose version &>/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose &>/dev/null; then
  DC="docker-compose"
else
  error "Docker Compose not found. It ships with Docker Desktop — make sure Docker Desktop is installed."
fi
ok "Docker Compose found: $($DC version --short 2>/dev/null || $DC version)"

# Check Docker daemon is actually running
if ! docker info &>/dev/null; then
  error "Docker daemon is not running. Please start Docker Desktop and try again."
fi
ok "Docker daemon is running"

# ── 2. Copy .env file ─────────────────────────────────────────
step "Setting up environment file"

if [[ ! -f "src/.env" ]]; then
  if [[ -f ".env.docker" ]]; then
    cp .env.docker src/.env
    ok "Copied .env.docker → src/.env"
  elif [[ -f ".env.docker.example" ]]; then
    cp .env.docker.example src/.env
    warn "No .env.docker found — copied .env.docker.example instead"
    warn "→ Edit src/.env and replace all 'change_me' values before continuing"
    echo ""
    read -rp "  Press Enter once you've updated src/.env, or Ctrl+C to abort..."
  else
    error "Neither .env.docker nor .env.docker.example found. Are you in the project root?"
  fi
else
  warn "src/.env already exists — skipping copy (delete it to reset)"
fi

# ── 3. Optionally wipe volumes ────────────────────────────────
if [[ "$FRESH" == true ]]; then
  step "Fresh mode — removing existing volumes"
  $DC down -v --remove-orphans
  ok "Volumes removed"
fi

# ── 4. Build images ───────────────────────────────────────────
step "Building Docker images (this may take a few minutes on first run)"
$DC build
ok "Images built"

# ── 5. Start containers ───────────────────────────────────────
step "Starting containers"
$DC up -d
ok "Containers started"

# ── 6. Wait for MySQL to be healthy ──────────────────────────
step "Waiting for MySQL to be ready"
MAX_WAIT=60
WAITED=0
until $DC exec mysql mysqladmin ping -h localhost --silent 2>/dev/null; do
  if [[ $WAITED -ge $MAX_WAIT ]]; then
    error "MySQL did not become healthy within ${MAX_WAIT}s. Run: $DC logs mysql"
  fi
  printf "."
  sleep 2
  WAITED=$((WAITED + 2))
done
echo ""
ok "MySQL is ready"

# ── 7. Create Laravel project if src/ is empty ───────────────
step "Checking for Laravel project in src/"

if [[ ! -f "src/composer.json" ]]; then
  echo -e "  ${YELLOW}src/ is empty — creating a fresh Laravel project...${RESET}"
  echo -e "  ${CYAN}(This downloads Laravel via Composer — may take a minute)${RESET}\n"
  $DC run --rm composer create-project laravel/laravel .
  ok "Laravel project created in src/"

  # Re-copy .env now that Laravel created its own blank one
  cp src/.env.example src/.env 2>/dev/null || true
  if [[ -f ".env.docker" ]]; then
    cp .env.docker src/.env
    ok "Re-applied .env.docker → src/.env"
  elif [[ -f ".env.docker.example" ]]; then
    cp .env.docker.example src/.env
    ok "Re-applied .env.docker.example → src/.env"
  fi
else
  ok "Laravel project found in src/"
  # Run composer install in case vendor/ is missing (e.g. fresh clone with existing src/)
  $DC exec php composer install --no-interaction --prefer-dist
  ok "Composer dependencies installed"
fi

# ── 8. App key ────────────────────────────────────────────────
step "Generating application key"
if grep -q "^APP_KEY=$" src/.env 2>/dev/null || grep -q '^APP_KEY=""' src/.env 2>/dev/null; then
  $DC exec php php artisan key:generate
  ok "App key generated"
else
  warn "APP_KEY already set — skipping"
fi

# ── 9. Migrations ─────────────────────────────────────────────
step "Running database migrations"
$DC exec php php artisan migrate --force
ok "Migrations complete"

# ── Done ──────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║  ✔  Setup complete! Your app is ready.       ║${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${BOLD}Laravel App  ${RESET}→  ${CYAN}http://localhost:8080${RESET}"
echo -e "  ${BOLD}phpMyAdmin   ${RESET}→  ${CYAN}http://localhost:8081${RESET}"
echo -e "  ${BOLD}Mailpit      ${RESET}→  ${CYAN}http://localhost:8025${RESET}"
echo ""
echo -e "  Run ${CYAN}make help${RESET} to see all available commands."
echo ""
