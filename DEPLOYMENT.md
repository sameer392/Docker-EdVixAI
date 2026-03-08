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

## Cloudflare 521 Fix
If edvixai.com shows "521 Web server is down":

1. **Start containers:**
   ```bash
   cd /var/www/docker && docker compose up -d
   ```

2. **Test locally:** `curl -H "Host: edvixai.com" http://127.0.0.1:80/` — should return 200

3. **Cloud provider firewall:** AWS/GCP/DigitalOcean have their own firewalls. Add inbound rules for ports 80 and 443.

4. **Cloudflare DNS:** A record for edvixai.com must point to server's public IP:
   ```bash
   curl -s ifconfig.me   # Use this IP in Cloudflare
   ```

5. **Cloudflare SSL:** With `cloudflare` in sites.conf, set SSL mode to **Flexible** in Cloudflare dashboard.
