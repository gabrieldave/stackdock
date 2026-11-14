/**
 * Acceso a PostgreSQL 17 con `pg`. Pool perezoso + migración idempotente.
 * Si DATABASE_URL falta, el servidor arranca igual y las rutas de BD responden 503.
 */
import fs from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import pg from 'pg';
import { config } from './config.js';
import { encryptSecret, hashLicenseKey } from './crypto-store.js';

const SCHEMA_PATH = fileURLToPath(new URL('../db/schema.sql', import.meta.url));

let pool = null;
let migrated = false;

function sslSetting() {
  const mode = config.databaseSsl;
  if (mode === 'disable' || mode === 'false' || mode === 'off' || mode === '0') return false;
  if (mode === 'require' || mode === 'true' || mode === 'on' || mode === 'verify-full') {
    return { rejectUnauthorized: mode === 'verify-full' };
  }
  // auto: TLS solo para hosts remotos; redes internas de Docker/privadas sin TLS.
  try {
    const parsed = new URL(config.databaseUrl);
    const sslmode = String(parsed.searchParams.get('sslmode') || '').toLowerCase();
    if (sslmode === 'disable') return false;
    if (sslmode === 'require' || sslmode === 'verify-full') {
      return { rejectUnauthorized: sslmode === 'verify-full' };
    }

    const host = parsed.hostname;
    const internal =
      !host ||
      host === 'localhost' ||
      host === '::1' ||
      !host.includes('.') ||
      /^127\./.test(host) ||
      /^10\./.test(host) ||
      /^192\.168\./.test(host) ||
      /^172\.(1[6-9]|2\d|3[01])\./.test(host) ||
      /\.(internal|local|svc|cluster\.local)$/.test(host);
    return internal ? false : { rejectUnauthorized: false };
  } catch {
    return false;
  }
}

export function isDbConfigured() {
  return Boolean(config.databaseUrl);
}

export function getPool() {
  if (!config.databaseUrl) return null;
  if (!pool) {
    pool = new pg.Pool({
      connectionString: config.databaseUrl,
      ssl: sslSetting(),
      max: 5,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 8_000,
      application_name: 'stackdock-server',
    });
    pool.on('error', (error) => {
      console.error('[db] error en conexión idle:', error.message);
    });
  }
  return pool;
}

export async function query(text, params = []) {
  const active = getPool();
  if (!active) {
    const error = new Error('Base de datos no configurada');
    error.statusCode = 503;
    throw error;
  }
  return active.query(text, params);
}

export async function migrate() {
  const active = getPool();
  if (!active) {
    console.warn('[db] DATABASE_URL ausente: migración omitida (rutas de BD responderán 503)');
    return false;
  }
  const sql = await fs.readFile(SCHEMA_PATH, 'utf8');
  await active.query(sql);
  await encryptLegacyLicenses(active);
  migrated = true;
  console.log('[db] esquema verificado (idempotente)');
  return true;
}

export function isMigrated() {
  return migrated;
}

export async function closePool() {
  if (pool) {
    await pool.end().catch(() => {});
    pool = null;
  }
}

/**
 * Migra licencias legadas en texto plano a AES-256-GCM (idempotente).
 * Nunca deja copias en claro en la tabla.
 */
async function encryptLegacyLicenses(active) {
  if (!config.sessionSecret || config.sessionSecret.length < 16) return 0;
  let migratedRows = 0;
  for (let round = 0; round < 10; round += 1) {
    const result = await active.query(
      `SELECT id, license_key, findaro_key FROM orders
       WHERE (license_key IS NOT NULL AND license_key_enc IS NULL)
          OR (findaro_key IS NOT NULL AND findaro_key_enc IS NULL)
       LIMIT 500`,
    );
    if (!result.rows.length) break;
    for (const row of result.rows) {
      const licenseEnc = row.license_key ? encryptSecret(row.license_key, config.sessionSecret) : null;
      const licenseHash = row.license_key ? hashLicenseKey(row.license_key) : null;
      const findaroEnc = row.findaro_key ? encryptSecret(row.findaro_key, config.sessionSecret) : null;
      await active.query(
        `UPDATE orders
         SET license_key_enc = COALESCE($1, license_key_enc),
             license_key_hash = COALESCE($2, license_key_hash),
             findaro_key_enc = COALESCE($3, findaro_key_enc),
             license_key = NULL,
             findaro_key = NULL
         WHERE id = $4`,
        [licenseEnc, licenseHash, findaroEnc, row.id],
      );
      migratedRows += 1;
    }
    if (result.rows.length < 500) break;
  }
  if (migratedRows > 0) console.log('[db] licencias migradas a AES-256-GCM:', migratedRows);
  return migratedRows;
}
