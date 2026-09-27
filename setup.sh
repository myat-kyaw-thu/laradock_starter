#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

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
CLI_INSTALLED=false
for BIN_DIR in "$HOME/.local/bin" "/opt/homebrew/bin" "/usr/local/bin"; do
  if [[ -d "$BIN_DIR" && -w "$BIN_DIR" ]]; then
    ln -sf "$(pwd)/laradoc" "$BIN_DIR/laradoc"
    CLI_INSTALLED=true
    ok "LaraDoc CLI installed to $BIN_DIR/laradoc"
    break
  fi
done

if [[ "$CLI_INSTALLED" == false ]]; then
  mkdir -p "$HOME/.local/bin" 2>/dev/null || true
  if [[ -w "$HOME/.local/bin" ]]; then
    ln -sf "$(pwd)/laradoc" "$HOME/.local/bin/laradoc"
    ok "LaraDoc CLI installed to $HOME/.local/bin/laradoc"
    CLI_INSTALLED=true
  fi
fi

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
echo -e "  ${BOLD}LaraDoc CLI:${RESET}"
echo -e "    ${CYAN}laradoc artisan migrate${RESET}"
echo -e "    ${CYAN}laradoc composer install${RESET}"
echo -e "    ${CYAN}laradoc shell${RESET}"
echo -e "    ${CYAN}laradoc help${RESET}  (see all commands)"
echo ""
