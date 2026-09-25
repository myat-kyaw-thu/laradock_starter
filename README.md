<p align="center">
  <img src="Head.jpg" alt="LaraDoc Starter" width="100%" />
</p>

# LaraDoc Starter

A lightweight, multi-project Docker local environment for Laravel. Run multiple fully isolated Laravel projects simultaneously on **port 80** using local subdomains — powered by a single shared container stack.

No port conflicts, no heavy virtual machines, no complex DNS routing, no Nginx, no PHP-FPM.

---

## 🛠️ Stack

| Service | Version |
|---|---|
| **FrankenPHP** | 1 / PHP 8.4 (Alpine) |
| **MySQL** | 8.0 |
| **Redis** | 7 (Alpine) — optional |
| **phpMyAdmin** | 5.2 |
| **Mailpit** | v1.21 — optional |
| **Node / Vite** | 22 (Alpine) — optional |

> FrankenPHP embeds Caddy + PHP into a single binary. It replaces both Nginx and PHP-FPM — no FastCGI, one container instead of two.

---

## 🚀 Quick Start

> **Prerequisite:** [Docker Desktop](https://www.docker.com/products/docker-desktop) must be installed and running.

### Step 1 — Start the environment

```bash
# Windows
setup.bat

# Mac / Linux
bash setup.sh
```

This builds the FrankenPHP image and starts MySQL + phpMyAdmin. Once running, visit **http://localhost** to see your developer dashboard.

---

### Step 2 — Add a project

All projects live inside the `src/` folder. Pick the scenario that fits:

#### Scenario A — Fresh Laravel project
```bash
# Windows
add-project.bat my-app

# Mac / Linux
bash add-project.sh my-app
```

#### Scenario B — Clone from Git
```bash
# Windows
add-project.bat my-app --clone https://github.com/you/repo.git

# Mac / Linux
bash add-project.sh my-app --clone https://github.com/you/repo.git
```

#### Scenario C — Existing folder already in `src/`
```bash
# Windows
add-project.bat my-app --existing

# Mac / Linux
bash add-project.sh my-app --existing
```

**That's it.** The script handles everything:
- Creates the Caddy site config (`my-app.localhost` routing)
- Creates a MySQL database + dedicated user with a random password
- Generates `src/my-app/.env` with correct DB host, credentials, Redis isolation
- Runs `composer install`, `key:generate`, `migrate`
- Reloads FrankenPHP

Visit **http://my-app.localhost** — your app is live.

---

## 🌐 Local Domains & Services

All projects and tools run on **port 80** via subdomains. Browsers resolve `*.localhost` to `127.0.0.1` natively — no hosts file edits, no admin rights required.

| Service | URL |
|---|---|
| **Developer Dashboard** | http://localhost |
| **Your projects** | `http://[folder-name].localhost` |
| **phpMyAdmin** | http://phpmyadmin.localhost |
| **Mailpit inbox** | http://mailpit.localhost |
| **Mailpit SMTP** | `localhost:1025` |
| **MySQL** | `localhost:3306` |
| **Redis** | `localhost:6379` |
| **Vite HMR** | `http://[folder-name].localhost:[5173-5183]` |

---

## ⚙️ Common Commands

### Manage containers

```bash
# Start essential services (FrankenPHP, MySQL, phpMyAdmin)
docker compose up -d

# Start all services including Redis and Mailpit
docker compose --profile extras up -d

# Start with Vite / Node frontend
docker compose --profile frontend up -d

# Stop everything
docker compose down

# Rebuild FrankenPHP image (after Dockerfile changes)
docker compose build --no-cache

# View logs
docker compose logs -f
docker compose logs -f frankenphp
docker compose logs -f mysql

# Container status
docker compose ps
```

### Shell into the container

```bash
docker compose exec frankenphp bash
```

Once inside, `cd` into your project and run artisan / composer as normal:

```bash
cd my-app
php artisan migrate
php artisan tinker
php artisan queue:work
composer require some/package
```

### Run commands without entering the shell

```bash
# Artisan
docker compose exec frankenphp sh -c "cd /var/www/html/my-app && php artisan migrate"
docker compose exec frankenphp sh -c "cd /var/www/html/my-app && php artisan migrate:fresh --seed"
docker compose exec frankenphp sh -c "cd /var/www/html/my-app && php artisan db:seed"

# Composer
docker compose exec frankenphp sh -c "cd /var/www/html/my-app && composer install"
docker compose exec frankenphp sh -c "cd /var/www/html/my-app && composer update"

# MySQL shell
docker compose exec mysql mysql -u root -prootsecret

# Redis CLI
docker compose exec redis redis-cli
```

### Reload FrankenPHP after config changes

```bash
docker compose exec frankenphp frankenphp reload
```

---

## 🔒 Isolation Features

Each project gets its own fully sandboxed environment:

1. **MySQL isolation** — dedicated database user and random password per project. Root credentials are never used by apps.
2. **Redis isolation** — unique `REDIS_DB` index and `REDIS_PREFIX` / `CACHE_PREFIX` per project. No session or cache bleed between projects.
3. **Vite port isolation** — each project gets its own HMR port (auto-incremented from 5173).

---

## 🗂️ Project Structure

```
laradock-starter/
├── docker/
│   ├── frankenphp/
│   │   ├── Dockerfile                  # FrankenPHP image
│   │   ├── php.ini                     # PHP configuration
│   │   ├── Caddyfile                   # Main Caddy config
│   │   ├── conf.d/
│   │   │   ├── default.caddyfile       # Dashboard + phpMyAdmin + Mailpit
│   │   │   └── *.caddyfile             # Auto-generated per project
│   │   ├── dashboard/
│   │   │   └── index.php               # Developer dashboard
│   │   └── project.caddyfile.template  # Template for new project configs
│   └── mysql/
│       └── my.cnf                      # MySQL configuration
├── src/                                # All Laravel projects live here
├── docker-compose.yml
├── setup.bat / setup.sh                # First-time environment setup
├── add-project.bat / add-project.sh    # Add a Laravel project
└── .env.docker.example                 # Base .env template
```

---

## 🔧 Optional Services

Redis and Mailpit are off by default to keep the environment lean. Start them when needed:

```bash
# Redis only
docker compose up -d redis

# Mailpit only
docker compose up -d mailpit

# Both at once
docker compose --profile extras up -d
```

---

## 🐘 Switching PHP Version

The environment supports **PHP 8.2** and **PHP 8.4**. Default is 8.4.

1. Copy the example env file if you haven't already:
   ```bash
   cp .env.docker.example .env.docker
   ```

2. Edit `.env.docker` and set your version:
   ```bash
   PHP_VERSION=8.2   # or 8.4
   ```

3. Rebuild the FrankenPHP image:
   ```bash
   docker compose build --no-cache
   docker compose up -d
   ```

That's it. All projects in `src/` run on the selected version.

---

## ♻️ Fresh Reset

Wipe all volumes and start completely clean:

```bash
# Windows
setup.bat --fresh

# Mac / Linux
bash setup.sh --fresh
```
