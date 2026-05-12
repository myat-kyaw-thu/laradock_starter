# ============================================================
#  Laravel Docker — Developer Makefile
#  Run `make` or `make help` to see all available commands
# ============================================================

.DEFAULT_GOAL := help

# Detect docker compose v2 (plugin) vs v1 (standalone)
DOCKER_COMPOSE := $(shell docker compose version > /dev/null 2>&1 && echo "docker compose" || echo "docker-compose")

# PHP container name (matches docker-compose.yml)
PHP := $(DOCKER_COMPOSE) exec php

# ── Colours ──────────────────────────────────────────────────
RESET  = \033[0m
BOLD   = \033[1m
GREEN  = \033[32m
YELLOW = \033[33m
CYAN   = \033[36m

##@ 🚀 Project Setup

.PHONY: init
init: ## First-time setup — detects OS and runs the right script automatically
	@echo "$(CYAN)$(BOLD)Detecting operating system...$(RESET)"
	@if [ "$(OS)" = "Windows_NT" ]; then \
		echo "$(CYAN)▶ Windows detected — running setup.bat$(RESET)"; \
		cmd /c setup.bat; \
	else \
		echo "$(CYAN)▶ Unix detected — running setup.sh$(RESET)"; \
		bash setup.sh; \
	fi

.PHONY: init-fresh
init-fresh: ## Same as init but wipes all volumes first (clean slate)
	@echo "$(CYAN)$(BOLD)Detecting operating system...$(RESET)"
	@if [ "$(OS)" = "Windows_NT" ]; then \
		echo "$(CYAN)▶ Windows detected — running setup.bat --fresh$(RESET)"; \
		cmd /c setup.bat --fresh; \
	else \
		echo "$(CYAN)▶ Unix detected — running setup.sh --fresh$(RESET)"; \
		bash setup.sh --fresh; \
	fi

.PHONY: install
install: ## Full first-time setup: build → up → composer install → key → migrate
	@echo "$(CYAN)▶ Building images...$(RESET)"
	$(DOCKER_COMPOSE) build
	@echo "$(CYAN)▶ Starting containers...$(RESET)"
	$(DOCKER_COMPOSE) up -d
	@echo "$(CYAN)▶ Installing Composer dependencies...$(RESET)"
	$(PHP) composer install
	@echo "$(CYAN)▶ Generating app key...$(RESET)"
	$(PHP) php artisan key:generate
	@echo "$(CYAN)▶ Running migrations...$(RESET)"
	$(PHP) php artisan migrate
	@echo "$(GREEN)✔ Setup complete! App → http://localhost:8080$(RESET)"

.PHONY: setup
setup: ## Alias for install (friendlier name for new devs)
	@$(MAKE) install

##@ 🐳 Docker

.PHONY: up
up: ## Start backend containers only (no Vite). Use 'make dev' to include frontend
	$(DOCKER_COMPOSE) up -d

.PHONY: down
down: ## Stop and remove containers
	$(DOCKER_COMPOSE) down

.PHONY: restart
restart: ## Restart all containers
	$(DOCKER_COMPOSE) restart

.PHONY: build
build: ## Rebuild images (no cache)
	$(DOCKER_COMPOSE) build --no-cache

.PHONY: pull
pull: ## Pull latest versions of all pre-built images
	$(DOCKER_COMPOSE) pull

.PHONY: ps
ps: ## Show running containers and their status
	$(DOCKER_COMPOSE) ps

.PHONY: prune
prune: ## Remove stopped containers, unused images and volumes (careful!)
	@echo "$(YELLOW)⚠ This will remove unused Docker resources. Continue? [y/N]$(RESET)" && read ans && [ $${ans:-N} = y ]
	docker system prune -f
	docker volume prune -f

##@ 📋 Logs

.PHONY: logs
logs: ## Tail logs from all containers
	$(DOCKER_COMPOSE) logs -f

.PHONY: logs-php
logs-php: ## Tail PHP container logs only
	$(DOCKER_COMPOSE) logs -f php

.PHONY: logs-nginx
logs-nginx: ## Tail Nginx container logs only
	$(DOCKER_COMPOSE) logs -f nginx

.PHONY: logs-mysql
logs-mysql: ## Tail MySQL container logs only
	$(DOCKER_COMPOSE) logs -f mysql

##@ 🐚 Shell Access

.PHONY: shell
shell: ## Open a bash shell inside the PHP container
	$(DOCKER_COMPOSE) exec php bash

.PHONY: shell-mysql
shell-mysql: ## Open a MySQL shell (reads credentials from .env.docker)
	$(DOCKER_COMPOSE) exec mysql mysql -u $$(grep MYSQL_USER .env.docker | cut -d= -f2) -p$$(grep MYSQL_PASSWORD .env.docker | cut -d= -f2) $$(grep MYSQL_DATABASE .env.docker | cut -d= -f2)

.PHONY: shell-redis
shell-redis: ## Open a Redis CLI shell
	$(DOCKER_COMPOSE) exec redis redis-cli

##@ ⚙️  Artisan

.PHONY: migrate
migrate: ## Run database migrations
	$(PHP) php artisan migrate

.PHONY: migrate-fresh
migrate-fresh: ## Drop all tables and re-run migrations + seeders
	$(PHP) php artisan migrate:fresh --seed

.PHONY: seed
seed: ## Run database seeders
	$(PHP) php artisan db:seed

.PHONY: rollback
rollback: ## Rollback the last migration batch
	$(PHP) php artisan migrate:rollback

.PHONY: tinker
tinker: ## Open Laravel Tinker REPL
	$(PHP) php artisan tinker

.PHONY: queue
queue: ## Start the queue worker
	$(PHP) php artisan queue:work --verbose

.PHONY: cache-clear
cache-clear: ## Clear all Laravel caches (config, route, view, app)
	$(PHP) php artisan optimize:clear

.PHONY: optimize
optimize: ## Cache config, routes and views for performance
	$(PHP) php artisan optimize

##@ 📦 Composer

.PHONY: composer-install
composer-install: ## Run composer install
	$(PHP) composer install

.PHONY: composer-update
composer-update: ## Run composer update
	$(PHP) composer update

.PHONY: composer-dump
composer-dump: ## Regenerate Composer autoload files
	$(PHP) composer dump-autoload -o

##@ 🎨 Frontend (Node / Vite)

.PHONY: dev
dev: ## Start full stack WITH Vite HMR (php + nginx + node + all services)
	$(DOCKER_COMPOSE) --profile frontend up -d
	@echo "$(GREEN)✔ All services up including Vite HMR → http://localhost:5173$(RESET)"

.PHONY: npm-install
npm-install: ## Run npm install inside the node container
	$(DOCKER_COMPOSE) --profile frontend run --rm node npm install

.PHONY: npm-build
npm-build: ## Build frontend assets for production (npm run build)
	$(DOCKER_COMPOSE) --profile frontend run --rm node npm run build

.PHONY: npm-run
npm-run: ## Run any npm script  →  make npm-run SCRIPT=test
	$(DOCKER_COMPOSE) --profile frontend run --rm node npm run $(SCRIPT)

.PHONY: node-shell
node-shell: ## Open a shell inside the node container
	$(DOCKER_COMPOSE) --profile frontend run --rm node sh

.PHONY: vite-config
vite-config: ## Copy the Docker-ready vite.config.js stub into src/
	@if [ -f src/vite.config.js ]; then \
		echo "$(YELLOW)⚠ src/vite.config.js already exists — skipping. Delete it first to overwrite.$(RESET)"; \
	else \
		cp docker/vite.config.js src/vite.config.js; \
		echo "$(GREEN)✔ Copied docker/vite.config.js → src/vite.config.js$(RESET)"; \
	fi

##@ 🧪 Testing

.PHONY: test
test: ## Run the full PHPUnit test suite
	$(PHP) php artisan test

.PHONY: test-filter
test-filter: ## Run tests matching a filter  →  make test-filter FILTER=UserTest
	$(PHP) php artisan test --filter=$(FILTER)

.PHONY: test-coverage
test-coverage: ## Run tests with HTML coverage report (needs Xdebug)
	$(PHP) php artisan test --coverage-html coverage/

##@ 🔧 Code Quality

.PHONY: pint
pint: ## Run Laravel Pint (code style fixer)
	$(PHP) ./vendor/bin/pint

.PHONY: pint-test
pint-test: ## Check code style without fixing
	$(PHP) ./vendor/bin/pint --test

##@ ℹ️  Help

.PHONY: help
help: ## Show this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\n$(BOLD)Usage:$(RESET)\n  make $(CYAN)<target>$(RESET)\n"} \
		/^##@/ { printf "\n$(BOLD)%s$(RESET)\n", substr($$0, 5) } \
		/^[a-zA-Z_-]+:.*?##/ { printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 }' \
		$(MAKEFILE_LIST)
	@echo ""
