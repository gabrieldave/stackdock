#!/bin/sh
# Genera la config del sitio en /tmp (raíz de solo lectura) con las variables de Coolify.
set -eu
: "${CHECKOUT_UPSTREAM:=http://127.0.0.1:9/unconfigured}"
: "${NGINX_RESOLVER:=1.1.1.1 8.8.8.8}"
mkdir -p /tmp/nginx-conf /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp
esc() { printf '%s' "$1" | sed 's/[&#\\]/\\&/g'; }
sed -e "s#\${CHECKOUT_UPSTREAM}#$(esc "$CHECKOUT_UPSTREAM")#g" \
    -e "s#\${NGINX_RESOLVER}#$(esc "$NGINX_RESOLVER")#g" \
    /etc/nginx/stackdock.conf.template > /tmp/nginx-conf/site.conf
nginx -t -q
exec nginx -g 'daemon off;'
