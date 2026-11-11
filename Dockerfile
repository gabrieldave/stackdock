# StackDock Web — static landing (nginx alpine, multi-stage, no-root)
FROM nginx:1.27-alpine AS runtime

RUN apk add --no-cache wget \
 && addgroup -g 1001 -S web \
 && adduser -u 1001 -S web -G web \
 && mkdir -p /opt/stackdock-web /tmp/www \
 && chown -R web:web /opt/stackdock-web /tmp

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY Web/index.html /opt/stackdock-web/index.html
COPY Web/public/ /opt/stackdock-web/

RUN chmod +x /docker-entrypoint.sh \
 && chown -R web:web /opt/stackdock-web \
 && printf '%s\n' \
  'pid /tmp/nginx.pid;' \
  'error_log /tmp/nginx-error.log warn;' \
  'events { worker_connections 1024; }' \
  'http {' \
  '  include /etc/nginx/mime.types;' \
  '  default_type application/octet-stream;' \
  '  sendfile on;' \
  '  keepalive_timeout 65;' \
  '  client_body_temp_path /tmp/client_temp;' \
  '  proxy_temp_path /tmp/proxy_temp;' \
  '  fastcgi_temp_path /tmp/fastcgi_temp;' \
  '  uwsgi_temp_path /tmp/uwsgi_temp;' \
  '  scgi_temp_path /tmp/scgi_temp;' \
  '  include /etc/nginx/conf.d/*.conf;' \
  '}' \
  > /etc/nginx/nginx.conf \
 && chown web:web /etc/nginx/nginx.conf /etc/nginx/conf.d/default.conf

USER web
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/api/health || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
