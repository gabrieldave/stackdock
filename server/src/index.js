/**
 * Arranque del backend StackDock (Node 22, sin frameworks).
 */
import http from 'node:http';
import { config, describeConfig } from './config.js';
import { closePool, migrate } from './db.js';
import { createHandler } from './app.js';

const server = http.createServer(createHandler());
server.keepAliveTimeout = 65_000;
server.headersTimeout = 70_000;
server.requestTimeout = 30_000;

server.on('clientError', (error, socket) => {
  if (socket.writable) socket.end('HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n');
});

server.on('error', (error) => {
  console.error('[fatal] servidor:', error.message);
  process.exit(1);
});

server.listen(config.port, '0.0.0.0', () => {
  console.log(`[boot] StackDock v${config.version} escuchando en 0.0.0.0:${config.port}`);
  console.log('[boot] configuración:', JSON.stringify(describeConfig()));
});

async function migrateWithRetry(attempts = 5) {
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      await migrate();
      return true;
    } catch (error) {
      console.error(`[db] migración falló (intento ${attempt}/${attempts}):`, error.message);
      if (attempt < attempts) {
        await new Promise((resolve) => setTimeout(resolve, Math.min(2000 * attempt, 10_000)));
      }
    }
  }
  console.error('[db] migración no completada; el servidor sigue activo y las rutas de BD responden 503');
  return false;
}

migrateWithRetry();

let shuttingDown = false;
async function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`[boot] ${signal} recibido, cerrando…`);
  const force = setTimeout(() => process.exit(1), 10_000);
  force.unref();
  await new Promise((resolve) => server.close(resolve));
  await closePool();
  process.exit(0);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('unhandledRejection', (error) => {
  console.error('[fatal] promesa rechazada:', error?.message || error);
});
