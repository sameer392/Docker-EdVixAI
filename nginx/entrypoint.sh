#!/bin/sh
set -e

SITES_FILE="${SITES_FILE:-/etc/nginx/sites.conf}"
CONF_DIR="/etc/nginx/conf.d"
CERTBOT_WEBROOT="/var/certbot-webroot"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@example.com}"
LETSENCRYPT_STAGING="${LETSENCRYPT_STAGING:-0}"

CERTBOT_OPTS="--webroot -w ${CERTBOT_WEBROOT} --email ${LETSENCRYPT_EMAIL} --agree-tos --non-interactive --keep-until-expiring"
[ "$LETSENCRYPT_STAGING" = "1" ] && CERTBOT_OPTS="${CERTBOT_OPTS} --staging"

# Get primary domain for cert path (.domain -> domain for /etc/letsencrypt/live/domain/)
get_cert_domain() {
    echo "$1" | awk '{print $1}' | sed 's/^\.//'
}

# Convert nginx server_name to certbot -d list (.rbill.in -> rbill.in www.rbill.in)
get_certbot_domains() {
    for d in $1; do
        if echo "$d" | grep -q '^\.'; then
            base=$(echo "$d" | sed 's/^\.//')
            echo "$base www.${base}"
        else
            echo "$d"
        fi
    done | tr '\n' ' ' | tr -s ' '
}

# Check if cert exists for domain
cert_exists() {
    [ -d "/etc/letsencrypt/live/$(get_cert_domain "$1")" ]
}

# Parse sites.conf and write config. $1 = "http" | "https" ; $2 = after certbot (1=use cert status)
generate_config() {
    rm -f "${CONF_DIR}"/*.conf
    vhost_num=0
    after_certbot="${2:-0}"

    if [ -f "$SITES_FILE" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            line=$(echo "$line" | sed 's/^[[:space:]]*#.*//' | sed 's/^[[:space:]]*//')
            [ -z "$line" ] && continue

            if echo "$line" | grep -q ' => '; then
                rest=$(echo "$line" | sed 's/.* => //')
                domain=$(echo "$line" | sed 's/ => .*//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                root=$(echo "$rest" | awk '{print $1}')
                flag=$(echo "$rest" | awk '{print $2}')
            else
                domain=$(echo "$line" | awk '{print $1}')
                root=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ *//')
                flag=""
            fi

            [ -z "$domain" ] || [ -z "$root" ] && continue

            is_ssl=0
            [ "$flag" = "ssl" ] && is_ssl=1

            vhost_num=$((vhost_num + 1))
            conf_file="${CONF_DIR}/vhost-${vhost_num}.conf"

            if [ "$1" = "http" ]; then
                use_redirect=0
                # Only redirect when we have a cert (after certbot ran and succeeded)
                if [ $is_ssl -eq 1 ] && [ $after_certbot -eq 1 ] && cert_exists "$domain"; then
                    use_redirect=1
                fi
                if [ $use_redirect -eq 1 ]; then
                    sed -e "s|{{DOMAIN}}|$domain|g" -e "s|{{ROOT}}|$root|g" /etc/nginx/templates/site-http-redirect.template > "$conf_file"
                else
                    sed -e "s|{{DOMAIN}}|$domain|g" -e "s|{{ROOT}}|$root|g" /etc/nginx/templates/site-http.template > "$conf_file"
                fi
            fi
        done < "$SITES_FILE"
    fi

    if [ -z "$(ls -A ${CONF_DIR} 2>/dev/null)" ]; then
        sed -e "s|{{DOMAIN}}|localhost|g" -e "s|{{ROOT}}|/var/www/html|g" /etc/nginx/templates/site-http.template > "${CONF_DIR}/default.conf"
    fi
}

# Append HTTPS blocks to vhost files for ssl sites
append_https_blocks() {
    vhost_num=0
    if [ -f "$SITES_FILE" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            line=$(echo "$line" | sed 's/^[[:space:]]*#.*//' | sed 's/^[[:space:]]*//')
            [ -z "$line" ] && continue
            if echo "$line" | grep -q ' => '; then
                rest=$(echo "$line" | sed 's/.* => //')
                domain=$(echo "$line" | sed 's/ => .*//' | sed 's/^[[:space:]]*//')
                root=$(echo "$rest" | awk '{print $1}')
                flag=$(echo "$rest" | awk '{print $2}')
            else
                domain=$(echo "$line" | awk '{print $1}')
                root=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ *//')
                flag=""
            fi
            [ -z "$domain" ] || [ -z "$root" ] && continue
            vhost_num=$((vhost_num + 1))
            if [ "$flag" = "ssl" ]; then
                cert_domain=$(get_cert_domain "$domain")
                cert_path="/etc/letsencrypt/live/${cert_domain}"
                if [ -d "$cert_path" ]; then
                    sed -e "s|{{DOMAIN}}|$domain|g" -e "s|{{ROOT}}|$root|g" -e "s|{{CERT_PATH}}|$cert_path|g" /etc/nginx/templates/site-https.template >> "${CONF_DIR}/vhost-${vhost_num}.conf"
                fi
            fi
        done < "$SITES_FILE"
    fi
}

# Obtain certs for ssl sites
obtain_certs() {
    mkdir -p "$CERTBOT_WEBROOT/.well-known/acme-challenge"
    if [ ! -f "$SITES_FILE" ]; then return; fi

    while IFS= read -r line || [ -n "$line" ]; do
        line=$(echo "$line" | sed 's/^[[:space:]]*#.*//' | sed 's/^[[:space:]]*//')
        [ -z "$line" ] && continue

        if echo "$line" | grep -q ' => '; then
            rest=$(echo "$line" | sed 's/.* => //')
            domain=$(echo "$line" | sed 's/ => .*//' | sed 's/^[[:space:]]*//')
            flag=$(echo "$rest" | awk '{print $2}')
        else
            domain=$(echo "$line" | awk '{print $1}')
            flag=""
        fi

        [ "$flag" != "ssl" ] && continue

        cert_domains=$(get_certbot_domains "$domain")
        [ -z "$cert_domains" ] && continue

        cert_domain=$(get_cert_domain "$domain")
        if [ ! -d "/etc/letsencrypt/live/${cert_domain}" ]; then
            echo "Obtaining Let's Encrypt cert for: $cert_domains"
            certbot certonly $CERTBOT_OPTS -d $cert_domains || echo "Cert obtainment failed for $cert_domains (domain must point to this server)"
        fi
    done < "$SITES_FILE"
}

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
