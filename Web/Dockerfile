# StackDock web 4.0.6 · Vite + TS → nginx (Coolify, read_only + tmpfs /tmp)
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npm run typecheck && npm run prerender && npm run build:site

FROM nginx:1.27-alpine
RUN apk add --no-cache wget && rm -rf /etc/nginx/conf.d/* /usr/share/nginx/html/*
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/default.conf.template /etc/nginx/stackdock.conf.template
COPY nginx/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
COPY --from=build /app/dist /usr/share/nginx/html
# Variables en Coolify:
#   CHECKOUT_UPSTREAM  URL del webhook del Payment Gateway Universal (n8n) que responde { "url": "https://checkout..." }
#   NGINX_RESOLVER     DNS para ese host (127.0.0.11 si es un servicio interno de la red coolify)
ENV CHECKOUT_UPSTREAM="http://127.0.0.1:9/unconfigured" \
    NGINX_RESOLVER="1.1.1.1 8.8.8.8"
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=8s --retries=3 \
  CMD wget -qO- http://127.0.0.1/api/health || exit 1
ENTRYPOINT ["/docker-entrypoint.sh"]
