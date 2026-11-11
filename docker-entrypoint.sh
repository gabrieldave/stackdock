#!/bin/sh
set -eu

SRC="/opt/stackdock-web"
DST="/tmp/www"
mkdir -p "$DST"
cp -a "${SRC}/." "${DST}/"

INDEX="${DST}/index.html"

inject() {
  # $1 placeholder  $2 value
  ph="$1"
  val="$2"
  if [ -n "$val" ] && [ -f "$INDEX" ]; then
    # Escape sed specials in value
    esc=$(printf '%s' "$val" | sed -e 's/[\\/&|]/\\&/g')
    sed -i "s|${ph}|${esc}|g" "$INDEX"
  fi
}

inject '__STRIPE_CHECKOUT_URL__' "${STRIPE_CHECKOUT_URL:-}"
inject '__STRIPE_CHECKOUT_URL_PERSONAL__' "${STRIPE_CHECKOUT_URL_PERSONAL:-${STRIPE_CHECKOUT_URL:-}}"
inject '__STRIPE_CHECKOUT_URL_PRO__' "${STRIPE_CHECKOUT_URL_PRO:-}"
inject '__TRIAL_WEBHOOK_URL__' "${TRIAL_WEBHOOK_URL:-}"
inject '__DMG_SHA256__' "${DMG_SHA256:-3449e4976099f77f5b083fe9e4a5c6cfe01087821010dc13768eddac7f4a8920}"

exec nginx -g 'daemon off;'
