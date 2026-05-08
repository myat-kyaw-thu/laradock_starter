# Laravel Docker Environment

A complete local Laravel development environment — no Laragon, no XAMPP, no paid tools.

## Stack
- PHP 8.4-FPM
- Nginx (alpine)
- MySQL 8.0
- phpMyAdmin
- Redis 7
- Mailpit (local email testing)
- Node 22 / Vite (optional, for frontend)

## Folder Structure
```
laravel-docker/
├── docker/
│   ├── php/
│   │   ├── Dockerfile          ← Custom PHP 8.4 image with all Laravel extensions
│   │   └── php.ini             ← PHP settings
│   ├── nginx/
│   │   └── default.conf        ← Nginx server block for Laravel
│   ├── mysql/
│   │   └── my.cnf              ← MySQL config
│   └── vite.config.js          ← Docker-ready Vite config (copy into your project)
├── src/                        ← Your Laravel project lives here
├── docker-compose.yml
├── .env.docker.example         ← Copy to .env.docker and fill in values
├── Makefile                    ← All commands (run: make help)
├── setup.sh                    ← Auto-setup script (Mac/Linux)
├── setup.bat                   ← Auto-setup script (Windows)
└── README.md
```

---

## Quick Start

> **Only requirement: [Docker Desktop](https://www.docker.com/products/docker-desktop) installed and running.**

```bash
git clone https://github.com/your-username/laravel-docker
cd laravel-docker
make init
```

That's it. `make init` detects your OS and runs the right script automatically.
It will create a fresh Laravel project, configure the environment, run migrations,
and open the app at **http://localhost:8080**.

### Installing `make`

| OS | Command |
|---|---|
| **Windows** | `winget install GnuWin32.Make` |
| **macOS** | `xcode-select --install` *(already included)* |
| **Ubuntu / Debian** | `sudo apt install make` |
| **Fedora / RHEL** | `sudo dnf install make` |
| **Arch** | `sudo pacman -S make` |

### No `make`? No problem.

```bash
# Mac / Linux
bash setup.sh

# Windows
setup.bat
```

### Want a clean slate?
```bash
make init-fresh   # wipes volumes and starts over
```

---

## Access Points

| Service     | URL                    |
|-------------|------------------------|
| Laravel App | http://localhost:8080  |
| phpMyAdmin  | http://localhost:8081  |
| Mailpit UI  | http://localhost:8025  |
| MySQL       | localhost:3306         |
| Redis       | localhost:6379         |
| Vite HMR    | http://localhost:5173  |

---

## Daily Commands

```bash
make up          # start containers
make down        # stop containers
make shell       # bash into PHP container
make migrate     # run migrations
make logs        # tail all logs
make help        # see ALL available commands
```

---

## Frontend / Vite (optional)

```bash
make dev         # starts everything including Vite HMR
make vite-config # copies Docker-ready vite.config.js into src/
```

---

## Common Artisan & Composer

```bash
# Artisan
docker compose exec php php artisan make:controller UserController
docker compose exec php php artisan make:model Post -m
docker compose exec php php artisan queue:work

# Composer
docker compose exec php composer require laravel/sanctum

# Or use make shortcuts
make tinker
make migrate-fresh
make test
```





