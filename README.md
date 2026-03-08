# Docker Development Stack

A multi-container Docker setup with **nginx**, **PHP 8.4**, **MySQL**, **phpMyAdmin**, and **Redis**.

## Prerequisites

**Docker** and **Docker Compose** must be installed.

```bash
# Ubuntu/Debian - install Compose plugin (recommended)
sudo apt update
sudo apt install docker-compose-plugin

# Or standalone compose
sudo apt install docker-compose
```

Use `docker compose` (with space) if you have the plugin, or `docker-compose` (with hyphen) for standalone.

## Services

| Service    | Port | Description                    |
|------------|------|--------------------------------|
| nginx      | 80   | Web server, proxies PHP to FPM |
| php        | -    | PHP 8.4-FPM with PDO, Redis, GD |
| mysql      | 3306 | MySQL 8.0 database             |
| phpmyadmin | 8080 | Web UI for MySQL               |
| redis      | 6379 | Redis in-memory store          |
| websocket  | 8090 | Soketi WebSocket (Laravel Echo)|

## Quick Start

```bash
cd /root/docker
cp .env.example .env
cp nginx/sites.conf.example nginx/sites.conf
# Edit .env and nginx/sites.conf with your values
docker compose up -d
```

- **Website:** http://localhost
- **phpMyAdmin:** http://localhost:8080 — login with MySQL user (e.g. `root` / `MYSQL_ROOT_PASSWORD` or `appuser` / `MYSQL_PASSWORD`)
- **MySQL:** localhost:3306 (from host)
- **WebSocket:** ws://localhost:8090

## Data Persistence

All data uses host bind mounts — no data loss on `docker compose down` or Docker reinstall.

| Data | Host path | Notes |
|------|-----------|-------|
| Website code, storage, cache | `www/` | Laravel `storage/`, `bootstrap/cache/` live here |
| nginx sites | `nginx/sites.conf` | Copy from `sites.conf.example` (gitignored, like `.env`) |
| MySQL data | `docker/data/mysql/` | Auto-created on first run |
| Redis data | `docker/data/redis/` | Auto-created on first run |
| SSL certificates | `docker/data/certbot/conf/` | Let's Encrypt certs |
| Certbot challenges | `docker/data/certbot/www/` | ACME validation |
| **Credentials** | `docker/.env` | MySQL root/app user, Pusher keys — **backup this file** |

Docker creates data folders automatically on first run. Copy `.env.example` to `.env` and `nginx/sites.conf.example` to `nginx/sites.conf` before first run. Both are gitignored — your credentials and domain setup survive `git pull`.

**Backup:** Copy the `data/` and `www/` folders. Restore them after a fresh install and run `docker compose up -d`.

**Migrating from named volumes:** If you had data in the old setup, copy it before switching:
```bash
docker volume ls  # Find volume names (e.g. docker_mysql_data)
docker run --rm -v VOLUME_NAME:/from -v $(pwd)/data/mysql:/to alpine sh -c "cp -a /from/. /to/"
```

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and adjust:

```bash
cp .env.example .env
```

| Variable              | Default     | Description                    |
|-----------------------|-------------|--------------------------------|
| MYSQL_ROOT_PASSWORD   | rootpassword| MySQL root (required)          |
| MYSQL_DATABASE        | -           | Optional; create from phpMyAdmin |
| MYSQL_USER            | -           | Optional; create from phpMyAdmin |
| MYSQL_PASSWORD        | -           | Optional; for MYSQL_USER       |
| LETSENCRYPT_EMAIL     | admin@example.com | For Let's Encrypt (ssl) |
| LETSENCRYPT_STAGING   | 0           | Set to 1 for testing (staging) |
| PUSHER_APP_ID/KEY/SECRET | -    | WebSocket auth (match Laravel .env) |

**phpMyAdmin** (port 8080) shows a login form. Use **root** / `MYSQL_ROOT_PASSWORD`. Create databases and users from phpMyAdmin, or uncomment `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` in `.env` to auto-create them.

### Sites (nginx vhosts)

Sites are defined in `nginx/sites.conf`. Copy the template and customize:

```bash
cp nginx/sites.conf.example nginx/sites.conf
```

Then edit `nginx/sites.conf` with your domains. This file is **gitignored** (like `.env`) — your domain setup is not overwritten on `git pull`.

If `sites.conf` was already committed, untrack it: `git rm --cached nginx/sites.conf`

**Format:** `domains => path [ssl|cloudflare]`

| Flag        | Behaviour |
|-------------|-----------|
| **ssl**     | Let's Encrypt HTTPS. Domain must point to this server (DNS A record). |
| **cloudflare** | HTTP only. Cloudflare handles SSL at the edge (Flexible mode). |
| *(no flag)* | HTTP only. |

```
# Let's Encrypt for schools without Cloudflare
rbill.in .rbill.in => /var/www/rbill.in/public_html/public ssl
demo.learning-cube.com => /var/www/rbill.in/public_html/public ssl

# Cloudflare-proxied school (SSL at Cloudflare, HTTP to origin)
school.cloudflare.com => /var/www/rbill.in/public_html/public cloudflare
```

- `.rbill.in` — matches rbill.in and all subdomains
- **ssl** — Certbot obtains cert at startup; ensure port 80 is reachable from the internet
- **cloudflare** — No origin cert; Cloudflare Flexible SSL or use Cloudflare Origin Certificate separately

**Laravel:** Use the `public` folder as document root.

**Certificate renewal** — Add to host crontab:
```bash
0 0 * * * docker exec nginx /certbot-renew.sh
```

Restart nginx: `docker compose restart nginx`

### Application Code

- **Laravel:** `/root/www/rbill.in/public_html/` (docroot = `public_html/public`)
- **Default (localhost):** `/root/www/html/`

Mounted as `/var/www` in containers.

## PHP Extensions

The PHP image includes: `pdo_mysql`, `mysqli`, `redis`, `gd`, `zip`, `intl`, `opcache`, `bcmath`, `soap`, `fileinfo`, `mbstring`, and Composer.

**Supervisor** manages PHP-FPM and can run Laravel queue workers. To add a worker:
```bash
cp php/supervisor/conf.d/laravel-worker.conf.example php/supervisor/conf.d/laravel-worker.conf
# Edit the artisan path and rebuild
docker compose build php --no-cache && docker compose up -d php
```

## Connecting from PHP

- **MySQL:** host `mysql`, user/password from `.env`
- **Redis:** host `redis`, port `6379`
- **WebSocket:** host `websocket`, port `6001` (from other containers)

## WebSocket (Soketi)

Connect at `ws://YOUR-SERVER-IP:8090`.

### Pusher credentials (PUSHER_APP_ID, KEY, SECRET)

**You define these yourself** — Soketi is self-hosted and does not issue credentials. Use the same values in both Docker `.env` and Laravel `.env`.

- **Development:** Use simple placeholders, e.g. `app-id`, `app-key`, `app-secret`
- **Production:** Generate strong random values (see below)

**Generate production credentials:**
```bash
echo "PUSHER_APP_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null)"
echo "PUSHER_APP_KEY=$(openssl rand -hex 16)"
echo "PUSHER_APP_SECRET=$(openssl rand -hex 32)"
```

Keep `PUSHER_APP_SECRET` private; never expose it in frontend code.

### Laravel Echo config (match `.env`):

```javascript
// resources/js/bootstrap.js or similar
window.Echo = new Echo({
    broadcaster: 'pusher',
    key: process.env.MIX_PUSHER_APP_KEY,
    wsHost: window.location.hostname,
    wsPort: 8090,
    wssPort: 443,
    forceTLS: false,
});
```

### Laravel `.env` broadcasting:

```
BROADCAST_CONNECTION=pusher
PUSHER_APP_ID=app-id
PUSHER_APP_KEY=app-key
PUSHER_APP_SECRET=app-secret
PUSHER_HOST=localhost
PUSHER_PORT=8090
PUSHER_SCHEME=http
```

## Connecting from PHP (code)

```php
// MySQL
$pdo = new PDO(
    'mysql:host=mysql;dbname=app',
    getenv('MYSQL_USER') ?: 'appuser',
    getenv('MYSQL_PASSWORD') ?: 'apppassword'
);

// Redis
$redis = new Redis();
$redis->connect('redis', 6379);
```

## Commands

```bash
# Start (use docker-compose if docker compose fails)
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f

# Rebuild PHP after Dockerfile changes
docker compose build php --no-cache
docker compose up -d php
```

## Troubleshooting

### "Connection refused" / "Cannot connect to Docker daemon"
Docker service is not running. Start it:
```bash
sudo systemctl start docker
```

### "docker.socket failed to load" / "Device or resource busy"
Start `docker.socket` first (it provides the socket for Docker), then `docker`:

```bash
sudo systemctl start docker.socket
sudo systemctl start docker
```

If that fails, try:
```bash
sudo systemctl stop podman-docker.socket podman-docker.service 2>/dev/null
sudo rm -f /var/run/docker.sock /var/run/docker.pid
sudo systemctl daemon-reload
sudo systemctl start docker.socket
sudo systemctl start docker
```
