#!/usr/bin/env bash
# =============================================================
#  LaraDoc Starter — Environment Setup (Mac / Linux)
#  Usage: bash setup.sh [--fresh]
#
#  --fresh   Wipe all volumes and start clean
#
#  What this does:
#    1. Checks Docker is running
#    2. Builds the PHP image
#    3. Starts all containers (MySQL, Redis, Nginx, Mailpit, phpMyAdmin)
#    4. Waits for MySQL to be healthy
#
#  To add a Laravel project after this:
#    bash add-project.sh <name> <port>
#    e.g. bash add-project.sh my-app 8080
# =============================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

step()  { echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"; }
ok()    { echo -e "${GREEN}✔ $1${RESET}"; }
warn()  { echo -e "${YELLOW}⚠ $1${RESET}"; }
error() { echo -e "${RED}✖ $1${RESET}"; exit 1; }

FRESH=false
for arg in "$@"; do [[ "$arg" == "--fresh" ]] && FRESH=true; done

# ── Banner ───────────────────────────────────────────────────
echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║   LaraDoc Starter — Environment Setup ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${RESET}"

# ── 1. Check Docker ──────────────────────────────────────────
step "Checking Docker"

command -v docker &>/dev/null || error "Docker not installed. Get it from https://www.docker.com/products/docker-desktop"
docker info &>/dev/null       || error "Docker is not running. Start Docker Desktop and try again."

if docker compose version &>/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose &>/dev/null; then
  DC="docker-compose"
else
  error "Docker Compose not found. Install Docker Desktop."
fi

ok "Docker is ready ($($DC version --short 2>/dev/null || echo 'v2'))"

# ── 2. Fresh wipe ────────────────────────────────────────────
if [[ "$FRESH" == true ]]; then
  step "Fresh mode — wiping volumes and containers"
  $DC down -v --remove-orphans
  ok "Wiped."
fi

# ── 3. Build + Start ─────────────────────────────────────────
step "Building images and starting containers"
echo -e "  ${YELLOW}First run pulls/builds images — may take a few minutes${RESET}\n"

$DC up -d --build --remove-orphans
ok "Containers started."

# ── 4. Wait for MySQL ────────────────────────────────────────
step "Waiting for MySQL to be ready"

WAITED=0
MAX_WAIT=90
until $DC exec mysql mysqladmin ping -h localhost --silent 2>/dev/null; do
  [[ $WAITED -ge $MAX_WAIT ]] && error "MySQL not ready after ${MAX_WAIT}s. Run: $DC logs mysql"
  printf "."
  sleep 3
  WAITED=$((WAITED + 3))
done
echo ""
ok "MySQL is ready."

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║  ✔  Environment is up and running!           ║${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  Next step — add your first project:\n"
echo -e "    ${CYAN}bash add-project.sh my-app 8080${RESET}"
echo ""
echo -e "  Services:"
echo -e "    phpMyAdmin  →  ${CYAN}http://localhost:8081${RESET}"
echo -e "    Mailpit     →  ${CYAN}http://localhost:8025${RESET}"
echo ""
