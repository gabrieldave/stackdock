/**
 * Licencias StackDock firmadas con Ed25519 en el servidor.
 *
 * Payloads EXACTOS:
 *   personal -> `${email}|stackdock-personal|1mac`
 *   pro      -> `${email}|stackdock-pro|3macs`
 *   findaro  -> `${email}|findaro-solo|1mac`
 *
 * Clave privada: 32 bytes en base64 (prefijo DER PKCS#8) o PEM PKCS#8.
 * Sin clave configurada se responde 503 explícito; nunca se genera una clave falsa.
 */
import crypto from 'node:crypto';
import { config } from './config.js';

export const PLANS = {
  personal: { name: 'Personal', payload: 'stackdock-personal|1mac', macs: 1 },
  pro: { name: 'Pro', payload: 'stackdock-pro|3macs', macs: 3 },
  findaro: { name: 'Findaro Solo', payload: 'findaro-solo|1mac', macs: 1 },
};

const DER_ED25519_PKCS8_PREFIX = Buffer.from('302e020100300506032b657004220420', 'hex');

let cachedKey = null;
let cachedSource = null;

export function normalizeEmail(email) {
  return String(email ?? '').trim().toLowerCase();
}

export function isValidEmail(email) {
  const value = normalizeEmail(email);
  return value.length >= 5 && value.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value);
}

function httpError(message, statusCode) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

/** Convierte base64(32 bytes) o PEM PKCS#8 en un KeyObject privado Ed25519. */
export function parsePrivateKey(input) {
  const raw = String(input ?? '').trim();
  if (!raw) throw httpError('LICENSE_PRIVATE_KEY no configurada', 503);
  if (cachedKey && cachedSource === raw) return cachedKey;

  let key;
  try {
    if (raw.includes('BEGIN')) {
      const pem = raw.replace(/\\n/g, '\n');
      key = crypto.createPrivateKey({ key: pem, format: 'pem', type: 'pkcs8' });
    } else {
      const seed = Buffer.from(raw, 'base64');
      if (seed.length !== 32) {
        throw new Error(`se esperaban 32 bytes, recibidos ${seed.length}`);
      }
      const der = Buffer.concat([DER_ED25519_PKCS8_PREFIX, seed]);
      key = crypto.createPrivateKey({ key: der, format: 'der', type: 'pkcs8' });
    }
  } catch (error) {
    throw httpError(`LICENSE_PRIVATE_KEY inválida (${error.message})`, 503);
  }

  if (key.asymmetricKeyType !== 'ed25519') {
    throw httpError('LICENSE_PRIVATE_KEY no es una clave Ed25519', 503);
  }
  cachedKey = key;
  cachedSource = raw;
  return key;
}

function base64url(buffer) {
  return buffer.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

/**
 * Firma una licencia. `privateKeyInput` permite inyectar una clave en tests;
 * en producción se usa config.licensePrivateKey.
 * @returns {string} SDOCK-<base64url(signature)>
 */
export function signLicense(email, plan, privateKeyInput = config.licensePrivateKey) {
  const normalized = normalizeEmail(email);
  if (!isValidEmail(normalized)) throw httpError('Email inválido', 400);
  const planDef = PLANS[plan];
  if (!planDef) throw httpError('Plan inválido', 400);
  if (!privateKeyInput) throw httpError('Emisión de licencias no configurada', 503);

  const key = parsePrivateKey(privateKeyInput);
  const payload = Buffer.from(`${normalized}|${planDef.payload}`, 'utf8');
  const signature = crypto.sign(null, payload, key);
  return `SDOCK-${base64url(signature)}`;
}

/** Verificación local (tests / diagnóstico). */
export function verifyLicense(licenseKey, email, plan, publicKey) {
  const key = typeof publicKey === 'string'
    ? crypto.createPublicKey(publicKey.includes('BEGIN') ? { key: publicKey, format: 'pem' } : publicKey)
    : publicKey;
  const planDef = PLANS[plan];
  if (!planDef) return false;
  const match = /^SDOCK-([A-Za-z0-9_-]+)$/.exec(String(licenseKey || ''));
  if (!match) return false;
  const payload = Buffer.from(`${normalizeEmail(email)}|${planDef.payload}`, 'utf8');
  const signature = Buffer.from(match[1].replace(/-/g, '+').replace(/_/g, '/'), 'base64');
  try {
    return crypto.verify(null, payload, key, signature);
  } catch {
    return false;
  }
}

/** Deriva la clave pública Ed25519 de la clave privada configurada (sin exponer la privada). */
export function publicKeyFromPrivate(privateKeyInput = config.licensePrivateKey) {
  return crypto.createPublicKey(parsePrivateKey(privateKeyInput));
}
