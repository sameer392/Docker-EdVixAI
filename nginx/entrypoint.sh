#!/bin/sh
set -e

. /etc/nginx/sites-common.sh

# Main
echo "Generating initial HTTP config (all sites serve HTTP for ACME)..."
generate_config http 0

echo "Starting nginx..."
nginx &

sleep 3

# Obtain certs for ssl sites, then switch to HTTPS where cert exists
if command -v certbot >/dev/null 2>&1; then
    obtain_certs
    echo "Generating final config (redirect to HTTPS where cert exists)..."
    generate_config http 1
    append_https_blocks
    nginx -s reload 2>/dev/null || true
fi

wait
