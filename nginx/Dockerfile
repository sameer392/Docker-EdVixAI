FROM nginx:alpine

# Install certbot for Let's Encrypt
RUN apk add --no-cache certbot

# Remove default config - we generate from sites.conf
RUN rm -f /etc/nginx/conf.d/default.conf

# Copy templates
COPY templates/site-http.template /etc/nginx/templates/site-http.template
COPY templates/site-http-redirect.template /etc/nginx/templates/site-http-redirect.template
COPY templates/site-https.template /etc/nginx/templates/site-https.template

COPY entrypoint.sh /entrypoint.sh
COPY certbot-renew.sh /certbot-renew.sh
RUN chmod +x /entrypoint.sh /certbot-renew.sh

COPY sites.conf /etc/nginx/sites.conf

ENTRYPOINT ["/entrypoint.sh"]
