#!/bin/bash
# Allow Cloudflare IP ranges - run if Cloudflare proxy returns 521 but direct IP works
# Ref: https://www.cloudflare.com/ips-v4

for ip in $(curl -s https://www.cloudflare.com/ips-v4); do
  sudo iptables -D DOCKER-USER -p tcp -s $ip --dport 80 -j ACCEPT 2>/dev/null
  sudo iptables -D DOCKER-USER -p tcp -s $ip --dport 443 -j ACCEPT 2>/dev/null
  sudo iptables -I DOCKER-USER -p tcp -s $ip --dport 80 -j ACCEPT
  sudo iptables -I DOCKER-USER -p tcp -s $ip --dport 443 -j ACCEPT
done
echo "Cloudflare IPs allowed. Ensure DOCKER-USER chain permits established traffic."
