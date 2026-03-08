FROM nginx:alpine

# Install certbot for Let's Encrypt
RUN apk add --no-cache certbot

# Remove default config - we generate from sites.conf
RUN rm -f /etc/nginx/conf.d/default.conf

# Copy templates
COPY templates/site-http.template /etc/nginx/templates/site-http.template
COPY templates/site-http-redirect.template /etc/nginx/templates/site-http-redirect.template
COPY templates/site-https.template /etc/nginx/templates/site-https.template

COPY sites-common.sh /etc/nginx/sites-common.sh
COPY entrypoint.sh /entrypoint.sh
COPY certbot-renew.sh /certbot-renew.sh
COPY reload-sites.sh /reload-sites.sh
RUN chmod +x /entrypoint.sh /certbot-renew.sh /reload-sites.sh

# Default fallback; compose mounts sites.conf over this at runtime
COPY sites.conf.example /etc/nginx/sites.conf

ENTRYPOINT ["/entrypoint.sh"]
