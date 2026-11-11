#!/bin/sh
set -eu
SRC="/opt/stackdock-web"
DST="/tmp/www"
mkdir -p "$DST" \
  /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp
cp -a "${SRC}/." "${DST}/"

# nginx intenta chown de temp paths al UID 101; con cap_drop:ALL falla si no existen ya.
if id -u nginx >/dev/null 2>&1; then
  chown -R nginx:nginx \
    /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp \
    "$DST" 2>/dev/null || true
fi

INDEX="${DST}/index.html"
STRIPE_URL="${STRIPE_CHECKOUT_URL:-}"
if [ -n "$STRIPE_URL" ] && [ -f "$INDEX" ]; then
  sed -i "s|__STRIPE_CHECKOUT_URL__|${STRIPE_URL}|g" "$INDEX"
fi

exec nginx -g 'daemon off;'
