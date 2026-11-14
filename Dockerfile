# StackDock 4.0.6 — web prerenderizada (Vite) + backend Node 22 + PostgreSQL 17
# Compatible con read_only: solo escribe en /app/storage y /tmp.

# ─────────────────────────── builder: web ───────────────────────────
FROM node:22-alpine AS web-builder
WORKDIR /app/web
COPY Web/package.json Web/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY Web/ ./
RUN npm run build

# ─────────────────────────── runtime ───────────────────────────
FROM node:22-alpine AS runtime
ENV NODE_ENV=production \
    PORT=8080 \
    PUBLIC_DIR=/app/public \
    STORAGE_DIR=/app/storage

RUN apk add --no-cache wget \
 && addgroup -g 1001 -S stackdock \
 && adduser -u 1001 -S stackdock -G stackdock -h /app

WORKDIR /app

COPY server/package.json server/package-lock.json ./server/
RUN cd server \
 && npm ci --omit=dev --no-audit --no-fund \
 && npm cache clean --force

COPY server/src ./server/src
COPY server/db ./server/db
COPY --from=web-builder /app/web/dist ./public

RUN mkdir -p /app/storage && chown -R stackdock:stackdock /app

USER stackdock
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/api/health || exit 1

ENTRYPOINT ["node", "server/src/index.js"]
