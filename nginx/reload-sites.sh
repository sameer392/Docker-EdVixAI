#!/bin/sh
# Reload sites.conf without restarting nginx (zero downtime).
# Run from host: docker exec nginx /reload-sites.sh
#
# Regenerates vhost configs, obtains new SSL certs if needed, then nginx -s reload.
set -e

. /etc/nginx/sites-common.sh

echo "Reloading sites from $SITES_FILE..."

# Obtain certs for any new ssl sites
if command -v certbot >/dev/null 2>&1; then
    obtain_certs
fi

# Regenerate config (use cert status for redirects)
generate_config http 1
append_https_blocks

# Graceful reload - no connection drop
nginx -t && nginx -s reload
echo "Sites reloaded."
