#!/bin/sh
set -eu

SRC="/opt/stackdock-web"
DST="/tmp/www"
mkdir -p "$DST"
cp -a "${SRC}/." "${DST}/"

inject_file() {
  file="$1"
  ph="$2"
  val="$3"
  if [ -n "$val" ] && [ -f "$file" ]; then
    esc=$(printf '%s' "$val" | sed -e 's/[\\/&|]/\\&/g')
    sed -i "s|${ph}|${esc}|g" "$file"
  fi
}

inject_all() {
  ph="$1"
  val="$2"
  inject_file "${DST}/index.html" "$ph" "$val"
  inject_file "${DST}/es/index.html" "$ph" "$val"
}

inject_all '__STRIPE_CHECKOUT_URL__' "${STRIPE_CHECKOUT_URL:-}"
inject_all '__STRIPE_CHECKOUT_URL_PERSONAL__' "${STRIPE_CHECKOUT_URL_PERSONAL:-${STRIPE_CHECKOUT_URL:-}}"
inject_all '__STRIPE_CHECKOUT_URL_PRO__' "${STRIPE_CHECKOUT_URL_PRO:-}"
inject_all '__TRIAL_WEBHOOK_URL__' "${TRIAL_WEBHOOK_URL:-}"
inject_all '__DMG_SHA256__' "${DMG_SHA256:-3449e4976099f77f5b083fe9e4a5c6cfe01087821010dc13768eddac7f4a8920}"
inject_all '__ENABLE_FINDARO_BUMP__' "${ENABLE_FINDARO_BUMP:-0}"

exec nginx -g 'daemon off;'
