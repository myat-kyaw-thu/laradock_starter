#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

step()  { echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"; }
ok()    { echo -e "${GREEN}✔ $1${RESET}"; }
error() { echo -e "${RED}✖ $1${RESET}"; exit 1; }

FRESH=false
for arg in "$@"; do [[ "$arg" == "--fresh" ]] && FRESH=true; done

echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║   LaraDoc Starter — Environment Setup ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${RESET}"

step "Checking Docker"
command -v docker &>/dev/null || error "Docker not installed. Get it from https://www.docker.com/products/docker-desktop"
docker info &>/dev/null       || error "Docker is not running. Start Docker Desktop and try again."

if docker compose version &>/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose &>/dev/null; then
  DC="docker-compose"
else
  error "Docker Compose not found."
fi
ok "Docker is ready"

if [[ "$FRESH" == true ]]; then
  step "Fresh mode — wiping volumes and containers"
  $DC down -v --remove-orphans
  ok "Wiped."
fi

step "Pulling images and starting containers"
for C in laravel_frankenphp laravel_mysql laravel_redis laravel_phpmyadmin laravel_mailpit; do
  docker rm -f "$C" &>/dev/null || true
done

# Try pulling pre-built images first (pulls in ~20s; falls back to local build if unavailable)
$DC pull --ignore-buildable-pull-failures 2>/dev/null || true

$DC up -d --remove-orphans
ok "Containers started."

step "Waiting for MySQL to be ready"
WAITED=0; MAX_WAIT=90
until $DC exec mysql mysqladmin ping -h localhost --silent 2>/dev/null; do
  [[ $WAITED -ge $MAX_WAIT ]] && error "MySQL not ready after ${MAX_WAIT}s. Run: $DC logs mysql"
  printf "."; sleep 3; WAITED=$((WAITED + 3))
done
echo ""
ok "MySQL is ready."

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║  ✔  Environment is up and running!           ║${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  Next step — add your first project:"
echo -e "    ${CYAN}bash add-project.sh my-app${RESET}"
echo ""
echo -e "  Dashboard   →  ${CYAN}http://localhost${RESET}"
echo -e "  phpMyAdmin  →  ${CYAN}http://phpmyadmin.localhost${RESET}"
echo -e "  Mailpit     →  ${CYAN}http://mailpit.localhost${RESET}  (docker compose --profile extras up -d)"
echo ""
