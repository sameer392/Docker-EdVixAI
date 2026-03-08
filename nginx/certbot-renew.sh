#!/bin/sh
# Run from host cron: docker exec nginx /certbot-renew.sh
# Or: 0 0 * * * docker exec nginx /certbot-renew.sh
certbot renew --webroot -w /var/www/certbot --quiet && nginx -s reload
