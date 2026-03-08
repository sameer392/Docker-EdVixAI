# Deployment Notes

## Project Location
Docker stack lives at **`/var/www/docker`** (moved from `/var/docker`).

Websites: `/var/www/edvixai.com/public_html/` etc.

## Start / Stop
```bash
cd /var/www/docker
docker compose up -d
docker compose down
```

## Cloudflare 521 Fix (Direct IP works but domain doesn't)
When the site loads via `http://208.110.95.204/` but not via `edvixai.com`, Cloudflare can't reach the origin.

### Quick workaround: Bypass Cloudflare (DNS only)
In Cloudflare → DNS → find `edvixai.com` A record → click the **orange cloud** to turn it **grey** (DNS only).
Site will work immediately. You lose CDN/DDoS protection until proxy is fixed.

### Fix the proxy
1. **Cloud provider firewall** (most common): Log into your hosting dashboard (DigitalOcean, AWS, Vultr, etc.). Find the **Firewall** or **Security Group** for this server. Add inbound rules: allow **port 80** and **port 443** from **0.0.0.0/0** (anywhere). Cloud provider firewalls are separate from UFW.

2. **Cloudflare A record:** Must point to server IP. Run `curl -4 -s ifconfig.me` to get it.

3. **Cloudflare SSL:** Set to **Flexible** (origin is HTTP-only).

4. **Contact hosting support:** Ask if they block Cloudflare IP ranges—some hosts do.
