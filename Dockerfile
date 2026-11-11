# Coolify (raíz): misma imagen que Web/Dockerfile
FROM nginx:1.27-alpine

RUN apk add --no-cache wget \
 && mkdir -p /opt/stackdock-web

COPY Web/nginx.conf /etc/nginx/conf.d/default.conf
COPY Web/docker-entrypoint.sh /docker-entrypoint.sh
COPY Web/index.html /opt/stackdock-web/index.html
COPY Web/es/ /opt/stackdock-web/es/
COPY Web/public/ /opt/stackdock-web/public/

RUN chmod +x /docker-entrypoint.sh \
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
  '}' > /etc/nginx/nginx.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=8s --retries=3 \
  CMD wget -qO- http://127.0.0.1/api/health || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
