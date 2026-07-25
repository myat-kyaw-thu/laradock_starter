# LaraDoc Starter Overhaul — Master Implementation Plan

This document contains the complete layout, architectural designs, and exact code changes required to overhaul the **LaraDoc Starter** Docker boilerplate. It configures the stack for domain-based routing on port 80, isolated database sandboxing, separate Redis database caching, customized Vite ports, and a project-aware CLI.

---

## 🎨 Architectural Design

1. **Port-Free Domain Routing (Port 80):** All apps are accessed via `http://[project-name].localhost`. Dynamic domains resolve to `127.0.0.1` locally, requiring no hosts file modifications. Helper tools are reverse-proxied over subdomains (`http://phpmyadmin.localhost`, `http://mailpit.localhost`).
2. **On-Demand Services (Speed Optimization):** `redis` and `mailpit` containers are mapped to the `extras` profile. By default, running the setup starts only Nginx, PHP, MySQL, and phpMyAdmin (essential stack). Redis and Mailpit can be spun up on-demand via dedicated make targets.
3. **WET Privilege Isolation:** Every project gets its own MySQL database schema and a dedicated database user with a secure random password (no shared root usage).
4. **Redis Namespace Partitioning:** Each project is assigned a unique Redis Database index (`REDIS_DB`) and unique key prefix (`REDIS_PREFIX`) in `.env` to prevent cache and queue job pollution.
5. **Local Dashboard:** Visiting `http://localhost` executes a PHP script that dynamically scans the local `src/` directory and renders cards for all active projects, detailing local domains, Laravel framework versions, and database schemas.

---

## 📂 File Changes Checklist

### 1. Nginx Routing Configurations

#### [docker/nginx/project.conf.template](file:///c:/Users/User/Downloads/laradock_starter-main/docker/nginx/project.conf.template)
Listen on port 80 and use the dynamic subdomain:
```nginx
# ── Project: __PROJECT_NAME__ ──────────────────────────────────
server {
    listen 80;
    server_name __PROJECT_NAME__.localhost;

    root  /var/www/html/__PROJECT_NAME__/public;
    index index.php index.html;

    client_max_body_size 50M;

    gzip            on;
    gzip_types      text/plain text/css application/json application/javascript
                    text/xml application/xml text/javascript image/svg+xml;
    gzip_min_length 1024;

    access_log /var/log/nginx/__PROJECT_NAME__-access.log;
    error_log  /var/log/nginx/__PROJECT_NAME__-error.log;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass            php:9000;
        fastcgi_index           index.php;
        include                 fastcgi_params;
        fastcgi_param           SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param           PATH_INFO $fastcgi_path_info;
        fastcgi_read_timeout    120;
        fastcgi_connect_timeout 120;
    }

    location ~ /\. {
        deny all;
        return 404;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }
}
```

#### [docker/nginx/conf.d/default.conf](file:///c:/Users/User/Downloads/laradock_starter-main/docker/nginx/conf.d/default.conf)
Set up catch-all routing to the dashboard and define reverse proxies for helper services:
```nginx
# ── phpMyAdmin Reverse Proxy ──────────────────────────────────
server {
    listen 80;
    server_name phpmyadmin.localhost;

    client_max_body_size 50M;

    location / {
        proxy_pass http://phpmyadmin:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# ── Mailpit Web UI Reverse Proxy ──────────────────────────────
server {
    listen 80;
    server_name mailpit.localhost;

    location / {
        proxy_pass http://mailpit:8025;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSockets support for Mailpit real-time updates
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
    }
}

# ── Default Dashboard Catch-All ──────────────────────────────
server {
    listen 80 default_server;
    server_name _;

    root /var/www/dashboard;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass            php:9000;
        fastcgi_index           index.php;
        include                 fastcgi_params;
        fastcgi_param           SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param           PATH_INFO $fastcgi_path_info;
    }
}
```

---

### 2. Environment Dashboard Page

#### [docker/nginx/dashboard/index.php](file:///c:/Users/User/Downloads/laradock_starter-main/docker/nginx/dashboard/index.php)
Create a PHP homepage rendering active local subdomains:
```php
<?php
$htmlDir = '/var/www/html';
$projects = [];

if (is_dir($htmlDir)) {
    $dirs = array_filter(glob($htmlDir . '/*'), 'is_dir');
    foreach ($dirs as $dir) {
        $slug = basename($dir);
        $envPath = $dir . '/.env';
        
        $projectInfo = [
            'name' => ucfirst($slug),
            'url' => "http://{$slug}.localhost",
            'db' => 'N/A',
            'laravel_ver' => 'Unknown',
            'has_env' => false
        ];
        
        if (file_exists($envPath)) {
            $projectInfo['has_env'] = true;
            $lines = file($envPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            foreach ($lines as $line) {
                if (strpos(trim($line), '#') === 0) continue;
                $parts = explode('=', $line, 2);
                if (count($parts) === 2) {
                    $key = trim($parts[0]);
                    $val = trim(trim($parts[1]), '"\'');
                    if ($key === 'APP_NAME') $projectInfo['name'] = $val;
                    if ($key === 'APP_URL') $projectInfo['url'] = $val;
                    if ($key === 'DB_DATABASE') $projectInfo['db'] = $val;
                }
            }
        }
        
        $composerPath = $dir . '/composer.json';
        if (file_exists($composerPath)) {
            $composerData = json_decode(file_get_contents($composerPath), true);
            if (isset($composerData['require']['laravel/framework'])) {
                $projectInfo['laravel_ver'] = str_replace(['^', '~'], '', $composerData['require']['laravel/framework']);
            }
        }
        
        $projects[] = $projectInfo;
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LaraDoc Dashboard</title>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&family=Plus+Jakarta+Sans:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-color: #0b0f19;
            --card-bg: rgba(22, 28, 45, 0.4);
            --card-border: rgba(255, 255, 255, 0.05);
            --primary: #4f46e5;
            --primary-glow: rgba(79, 70, 229, 0.4);
            --accent: #06b6d4;
            --text-main: #f3f4f6;
            --text-muted: #9ca3af;
            --success: #10b981;
            --success-glow: rgba(16, 185, 129, 0.2);
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background-color: var(--bg-color);
            color: var(--text-main);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            overflow-x: hidden;
            background-image: 
                radial-gradient(circle at 10% 20%, rgba(79, 70, 229, 0.15) 0%, transparent 40%),
                radial-gradient(circle at 90% 80%, rgba(6, 182, 212, 0.1) 0%, transparent 40%);
        }
        header {
            padding: 2.5rem 2rem;
            max-width: 1200px;
            width: 100%;
            margin: 0 auto;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid var(--card-border);
        }
        .logo {
            display: flex;
            align-items: center;
            gap: 0.75rem;
            font-family: 'Outfit', sans-serif;
            font-size: 1.5rem;
            font-weight: 700;
            background: linear-gradient(135deg, #fff 30%, var(--text-muted) 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .logo span {
            background: linear-gradient(135deg, var(--accent) 0%, var(--primary) 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .system-services { display: flex; gap: 1rem; }
        .service-btn {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.6rem 1.2rem;
            border-radius: 9999px;
            font-size: 0.875rem;
            font-weight: 600;
            text-decoration: none;
            color: var(--text-main);
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            backdrop-filter: blur(12px);
        }
        .service-btn:hover {
            border-color: var(--primary);
            box-shadow: 0 0 15px var(--primary-glow);
            transform: translateY(-2px);
        }
        .service-btn svg { width: 16px; height: 16px; }
        main { flex: 1; padding: 3rem 2rem; max-width: 1200px; width: 100%; margin: 0 auto; }
        .hero { text-align: center; margin-bottom: 4rem; }
        .hero h1 {
            font-family: 'Outfit', sans-serif;
            font-size: 3rem;
            font-weight: 800;
            margin-bottom: 1rem;
            letter-spacing: -0.025em;
            background: linear-gradient(135deg, #fff 40%, var(--text-muted) 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .hero p { font-size: 1.1rem; color: var(--text-muted); max-width: 600px; margin: 0 auto; }
        .section-title {
            font-family: 'Outfit', sans-serif;
            font-size: 1.5rem;
            font-weight: 600;
            margin-bottom: 2rem;
            display: flex;
            align-items: center;
            gap: 0.75rem;
        }
        .section-title::after { content: ''; flex: 1; height: 1px; background: var(--card-border); }
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 2rem; margin-bottom: 4rem; }
        .card {
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 16px;
            padding: 1.75rem;
            position: relative;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            backdrop-filter: blur(12px);
            overflow: hidden;
        }
        .card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: linear-gradient(135deg, rgba(79, 70, 229, 0.05) 0%, transparent 100%);
            opacity: 0;
            transition: opacity 0.3s ease;
            pointer-events: none;
        }
        .card:hover {
            transform: translateY(-4px);
            border-color: rgba(79, 70, 229, 0.3);
            box-shadow: 0 10px 30px -10px rgba(0, 0, 0, 0.7);
        }
        .card:hover::before { opacity: 1; }
        .card-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 1.25rem; }
        .card-title { font-size: 1.25rem; font-weight: 700; color: #fff; letter-spacing: -0.01em; }
        .badge {
            font-size: 0.75rem;
            font-weight: 700;
            padding: 0.25rem 0.6rem;
            border-radius: 9999px;
            background: var(--success-glow);
            color: var(--success);
            border: 1px solid rgba(16, 185, 129, 0.2);
        }
        .metadata-list { margin-bottom: 2rem; font-size: 0.875rem; }
        .metadata-item { display: flex; justify-content: space-between; padding: 0.5rem 0; border-bottom: 1px dashed rgba(255, 255, 255, 0.05); }
        .metadata-item:last-child { border: none; }
        .metadata-label { color: var(--text-muted); }
        .metadata-value { font-weight: 600; color: var(--text-main); }
        .card-btn {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 0.5rem;
            width: 100%;
            padding: 0.8rem;
            border-radius: 8px;
            font-weight: 700;
            text-decoration: none;
            background: linear-gradient(135deg, var(--primary) 0%, #3b82f6 100%);
            color: #fff;
            box-shadow: 0 4px 12px rgba(79, 70, 229, 0.3);
            transition: all 0.2s ease;
        }
        .card-btn:hover { box-shadow: 0 6px 20px rgba(79, 70, 229, 0.5); transform: translateY(-1px); }
        .empty-state { text-align: center; padding: 4rem 2rem; background: var(--card-bg); border: 1px dashed var(--card-border); border-radius: 16px; grid-column: 1 / -1; }
        .empty-state h3 { font-size: 1.25rem; margin-bottom: 0.5rem; }
        .empty-state p { color: var(--text-muted); margin-bottom: 1.5rem; }
        .code-block { display: inline-block; background: rgba(0, 0, 0, 0.3); border: 1px solid var(--card-border); padding: 0.5rem 1rem; border-radius: 6px; font-family: monospace; font-size: 0.9rem; color: var(--accent); }
        footer { text-align: center; padding: 3rem 2rem; color: var(--text-muted); font-size: 0.875rem; border-top: 1px solid var(--card-border); margin-top: auto; }
    </style>
</head>
<body>
    <header>
        <div class="logo">LaraDoc <span>Starter</span></div>
        <div class="system-services">
            <a href="http://phpmyadmin.localhost" target="_blank" class="service-btn">phpMyAdmin</a>
            <a href="http://mailpit.localhost" target="_blank" class="service-btn">Mailpit</a>
        </div>
    </header>
    <main>
        <div class="hero">
            <h1>Local Development Dashboard</h1>
            <p>One Docker environment, multiple fully isolated Laravel projects. Zero configuration domain routing.</p>
        </div>
        <h2 class="section-title">Laravel Projects</h2>
        <div class="grid">
            <?php if (empty($projects)): ?>
                <div class="empty-state">
                    <h3>No projects found</h3>
                    <p>Get started by creating your first Laravel project in the environment.</p>
                    <div class="code-block">bash add-project.sh my-app</div>
                </div>
            <?php else: ?>
                <?php foreach ($projects as $project): ?>
                    <div class="card">
                        <div>
                            <div class="card-header">
                                <h3 class="card-title"><?= htmlspecialchars($project['name']) ?></h3>
                                <span class="badge">PHP 8.4</span>
                            </div>
                            <div class="metadata-list">
                                <div class="metadata-item">
                                    <span class="metadata-label">Local Domain</span>
                                    <span class="metadata-value" style="color: var(--accent);"><?= htmlspecialchars(str_replace('http://', '', $project['url'])) ?></span>
                                </div>
                                <div class="metadata-item">
                                    <span class="metadata-label">Database Schema</span>
                                    <span class="metadata-value"><?= htmlspecialchars($project['db']) ?></span>
                                </div>
                                <div class="metadata-item">
                                    <span class="metadata-label">Laravel Version</span>
                                    <span class="metadata-value">v<?= htmlspecialchars($project['laravel_ver']) ?></span>
                                </div>
                            </div>
                        </div>
                        <a href="<?= htmlspecialchars($project['url']) ?>" target="_blank" class="card-btn">Open Application</a>
                    </div>
                <?php endforeach; ?>
            <?php endif; ?>
        </div>
    </main>
    <footer>
        <p>LaraDoc Starter &copy; <?= date('Y') ?>. Powered by Docker Alpine and Nginx.</p>
    </footer>
</body>
</html>
```

---

### 3. Docker Compose Orchestration

#### [docker-compose.yml](file:///c:/Users/User/Downloads/laradock_starter-main/docker-compose.yml)
Update the container definitions:
- Bind Nginx to port `80` and `443` (subdomain proxy).
- Mount the local `/var/www/dashboard` path.
- Isolate `redis` and `mailpit` using Docker Compose `profiles: [extras]` and remove start dependencies from `php`.
- Open a range for Vite port HMR `5173-5183:5173-5183`.
```yaml
name: laradoc-starter

services:

  # ── PHP 8.4-FPM ───────────────────────────────────────────────
  php:
    build:
      context: ./docker/php
      dockerfile: Dockerfile
    container_name: laravel_php
    restart: unless-stopped
    working_dir: /var/www/html
    volumes:
      - ./src:/var/www/html
      - ./docker/nginx/dashboard:/var/www/dashboard
      - composer_cache:/home/laravel/.composer
    environment:
      - APP_ENV=local
    networks:
      - laravel
    depends_on:
      mysql:
        condition: service_healthy

  # ── Nginx ─────────────────────────────────────────────────────
  nginx:
    image: nginx:1.27-alpine
    container_name: laravel_nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./src:/var/www/html
      - ./docker/nginx/dashboard:/var/www/dashboard
      - ./docker/nginx/conf.d:/etc/nginx/conf.d
    networks:
      - laravel
    depends_on:
      - php

  # ── MySQL 8.0 ─────────────────────────────────────────────────
  mysql:
    image: mysql:8.0
    container_name: laravel_mysql
    restart: unless-stopped
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-rootsecret}
    volumes:
      - mysql_data:/var/lib/mysql
      - ./docker/mysql/my.cnf:/etc/mysql/conf.d/my.cnf:ro
    networks:
      - laravel
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "--silent"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  # ── phpMyAdmin ────────────────────────────────────────────────
  phpmyadmin:
    image: phpmyadmin:5.2
    container_name: laravel_phpmyadmin
    restart: unless-stopped
    environment:
      PMA_HOST: mysql
      PMA_PORT: 3306
      PMA_USER: root
      PMA_PASSWORD: ${MYSQL_ROOT_PASSWORD:-rootsecret}
      UPLOAD_LIMIT: 50M
    networks:
      - laravel
    depends_on:
      mysql:
        condition: service_healthy

  # ── Redis ─────────────────────────────────────────────────────
  redis:
    image: redis:7-alpine
    container_name: laravel_redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - laravel
    profiles:
      - extras

  # ── Mailpit ───────────────────────────────────────────────────
  mailpit:
    image: axllent/mailpit:v1.21
    container_name: laravel_mailpit
    restart: unless-stopped
    ports:
      - "1025:1025"
    networks:
      - laravel
    profiles:
      - extras

  # ── Composer (one-off runner) ─────────────────────────────────
  composer:
    image: composer:2.8
    working_dir: /var/www/html
    volumes:
      - ./src:/var/www/html
      - composer_cache:/tmp/composer
    environment:
      - COMPOSER_HOME=/tmp/composer
    entrypoint: ["composer"]
    networks:
      - laravel

  # ── Node / Vite (frontend — optional profile) ─────────────────
  node:
    image: node:22-alpine
    container_name: laravel_node
    restart: unless-stopped
    working_dir: /var/www/html
    volumes:
      - ./src:/var/www/html
      - node_modules:/var/www/html/node_modules
    ports:
      - "5173-5183:5173-5183"
    environment:
      - VITE_HOST=0.0.0.0
    command: sh -c "[ -d node_modules ] || npm install && npm run dev"
    networks:
      - laravel
    profiles:
      - frontend

networks:
  laravel:
    driver: bridge

volumes:
  mysql_data:
  redis_data:
  composer_cache:
  node_modules:
```

---

### 4. Provisioning Automation Scripts

#### [add-project.sh](file:///c:/Users/User/Downloads/laradock_starter-main/add-project.sh)
Automates project creation, MySQL isolated user setup, Redis parameter injection, and Nginx reload:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Colors
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

[[ -z "$PROJECT" ]] && error "Project name required.\nUsage: bash add-project.sh <name> [--clone <url>] [--existing]"

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --clone)    CLONE_MODE=true;    CLONE_URL="${2:-}"; shift 2 ;;
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

REDIS_DB_INDEX=$(ls -1 docker/nginx/conf.d/*.conf 2>/dev/null | wc -l || echo 0)
REDIS_DB_INDEX=$((REDIS_DB_INDEX + 1))
VITE_PORT=$((5173 + REDIS_DB_INDEX - 1))

echo -e "${BOLD}  Adding project: ${PROJECT}.localhost${RESET}"

# ── 1. Create project ────────────────────────────────────────
step "1/8" "Setting up project files"
if [[ "$EXISTING_MODE" == true ]]; then
  [[ -d "src/${PROJECT}" ]] || error "src/${PROJECT}/ not found."
  ok "Using existing project at src/${PROJECT}/"
elif [[ "$CLONE_MODE" == true ]]; then
  [[ -d "src/${PROJECT}" ]] && error "src/${PROJECT}/ already exists."
  git clone "$CLONE_URL" "src/${PROJECT}"
  ok "Cloned into src/${PROJECT}/"
else
  [[ -d "src/${PROJECT}" ]] && error "src/${PROJECT}/ already exists."
  $DC run --rm -w /var/www/html composer create-project laravel/laravel "${PROJECT}"
  ok "Laravel project created."
fi

# ── 2. Nginx config ──────────────────────────────────────────
step "2/8" "Creating Nginx config"
CONF="docker/nginx/conf.d/${PROJECT}.conf"
sed -e "s/__PROJECT_NAME__/${PROJECT}/g" docker/nginx/project.conf.template > "$CONF"
ok "Created ${CONF}"

# ── 3. Database ───────────────────────────────────────────────
step "3/8" "Creating database and dedicated user (WET isolation)"
DB_USER=$(echo "${PROJECT}" | tr '-' '_')
DB_PASS=$(openssl rand -hex 12 2>/dev/null || tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 16)

$DC exec mysql mysql -u root -prootsecret \
  -e "CREATE DATABASE IF NOT EXISTS \`${PROJECT}\`;
      CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
      GRANT ALL PRIVILEGES ON \`${PROJECT}\`.* TO '${DB_USER}'@'%';
      FLUSH PRIVILEGES;" \
  && ok "Database and isolated user '${DB_USER}' created." \
  || warn "Could not create database/user."

# ── 4. .env file ─────────────────────────────────────────────
step "4/8" "Setting up .env"
if [[ ! -f "src/${PROJECT}/.env" ]]; then
  cp .env.docker.example "src/${PROJECT}/.env"
  sed -i.bak \
    -e "s|^APP_NAME=.*|APP_NAME=${PROJECT}|" \
    -e "s|^APP_URL=.*|APP_URL=http://${PROJECT}.localhost|" \
    -e "s|^DB_DATABASE=.*|DB_DATABASE=${PROJECT}|" \
    -e "s|^DB_USERNAME=.*|DB_USERNAME=${DB_USER}|" \
    -e "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" \
    "src/${PROJECT}/.env"

  echo -e "\n# Isolation Settings\nREDIS_DB=${REDIS_DB_INDEX}\nREDIS_PREFIX=${PROJECT}_\nCACHE_PREFIX=${PROJECT}_cache" >> "src/${PROJECT}/.env"
  rm -f "src/${PROJECT}/.env.bak"
  ok "Created src/${PROJECT}/.env"
else
  warn "src/${PROJECT}/.env exists — skipping."
fi

# ── 5. Permissions ────────────────────────────────────────────
step "5/8" "Fixing permissions"
$DC exec --user root php chown -R laravel:laravel "/var/www/html/${PROJECT}" || true
$DC exec --user root php chmod -R 775 "/var/www/html/${PROJECT}/storage" "/var/www/html/${PROJECT}/bootstrap/cache" || true
ok "Permissions set."

# ── 6. Composer ───────────────────────────────────────────────
step "6/8" "Installing dependencies"
[[ ! -d "src/${PROJECT}/vendor" ]] && $DC exec php sh -c "cd /var/www/html/${PROJECT} && composer install --no-interaction"
ok "Dependencies installed."

# ── 7. Setup Tasks ────────────────────────────────────────────
step "7/8" "Running Laravel setup tasks"
$DC exec php sh -c "cd /var/www/html/${PROJECT} && php artisan key:generate --force && php artisan migrate --force"
if [[ ! -f "src/${PROJECT}/vite.config.js" ]]; then
  cp "docker/vite.config.js" "src/${PROJECT}/vite.config.js"
  sed -i.bak -e "s/port: 5173/port: ${VITE_PORT}/g" "src/${PROJECT}/vite.config.js"
  rm -f "src/${PROJECT}/vite.config.js.bak"
fi
ok "Setup tasks completed."

# ── 8. Reload Nginx ───────────────────────────────────────────
step "8/8" "Reloading Nginx"
$DC exec nginx nginx -s reload && ok "Nginx reloaded."

echo -e "\n${GREEN}✔ Project '${PROJECT}' is ready at http://${PROJECT}.localhost${RESET}\n"
```

---

### 5. Project Developer Makefile

#### [Makefile](file:///c:/Users/User/Downloads/laradock_starter-main/Makefile)
Update the task runners inside the Makefile:
```make
.DEFAULT_GOAL := help
DOCKER_COMPOSE := $(shell docker compose version > /dev/null 2>&1 && echo "docker compose" || echo "docker-compose")

PROJECTS := $(shell ls -1 src/ 2>/dev/null | grep -v '^\.' || echo "")

ifeq ($(words $(PROJECTS)), 1)
  DEFAULT_PROJECT := $(PROJECTS)
else
  DEFAULT_PROJECT :=
endif

PROJECT ?= $(DEFAULT_PROJECT)

ifeq ($(PROJECT),)
  PHP := @echo "Error: PROJECT variable is required. Example: make migrate PROJECT=my-app"; exit 1; #
else
  PHP := $(DOCKER_COMPOSE) exec php sh -c 'cd /var/www/html/$(PROJECT) && "$$@"' --
endif

RESET  = \033[0m
BOLD   = \033[1m
GREEN  = \033[32m
YELLOW = \033[33m
CYAN   = \033[36m

##@ 🚀 Project Setup
.PHONY: init
init:
	@if [ "$(OS)" = "Windows_NT" ]; then cmd /c setup.bat; else bash setup.sh; fi

.PHONY: init-fresh
init-fresh:
	@if [ "$(OS)" = "Windows_NT" ]; then cmd /c setup.bat --fresh; else bash setup.sh --fresh; fi

.PHONY: install
install:
	$(DOCKER_COMPOSE) build
	$(DOCKER_COMPOSE) up -d
	$(PHP) composer install
	$(PHP) php artisan key:generate
	$(PHP) php artisan migrate
	@echo "$(GREEN)✔ Setup complete! App → http://$(PROJECT).localhost$(RESET)"

.PHONY: setup
setup: install

##@ 🐳 Docker
.PHONY: up
up: ## Start essential containers only
	$(DOCKER_COMPOSE) up -d

.PHONY: up-all
up-all: ## Start all services including Redis and Mailpit
	$(DOCKER_COMPOSE) --profile extras up -d

.PHONY: redis
redis: ## Start the Redis service
	$(DOCKER_COMPOSE) up -d redis

.PHONY: mailpit
mailpit: ## Start the Mailpit service
	$(DOCKER_COMPOSE) up -d mailpit

.PHONY: down
down: ## Stop and remove containers
	$(DOCKER_COMPOSE) down --remove-orphans

.PHONY: restart
restart:
	$(DOCKER_COMPOSE) restart

.PHONY: build
build:
	$(DOCKER_COMPOSE) build --no-cache

.PHONY: ps
ps:
	$(DOCKER_COMPOSE) ps

##@ ⚙️  Artisan Commands
.PHONY: migrate
migrate:
	$(PHP) php artisan migrate

.PHONY: migrate-fresh
migrate-fresh:
	$(PHP) php artisan migrate:fresh --seed

.PHONY: tinker
tinker:
	$(PHP) php artisan tinker

.PHONY: queue
queue:
	$(PHP) php artisan queue:work

.PHONY: composer-install
composer-install:
	$(PHP) composer install

.PHONY: vite-config
vite-config:
	@if [ -z "$(PROJECT)" ]; then echo "Error: PROJECT is required."; exit 1; fi
	cp docker/vite.config.js src/$(PROJECT)/vite.config.js
```
