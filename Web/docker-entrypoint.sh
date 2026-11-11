#!/bin/sh
set -eu
SRC="/opt/stackdock-web"
DST="/tmp/www"
mkdir -p "$DST"
cp -a "${SRC}/." "${DST}/"

INDEX="${DST}/index.html"
STRIPE_URL="${STRIPE_CHECKOUT_URL:-}"
if [ -n "$STRIPE_URL" ] && [ -f "$INDEX" ]; then
  sed -i "s|__STRIPE_CHECKOUT_URL__|${STRIPE_URL}|g" "$INDEX"
fi

exec nginx -g 'daemon off;'
