/**
 * Cifrado en reposo de licencias: AES-256-GCM con clave derivada HKDF-SHA256.
 * Sin dependencias externas (node:crypto).
 *
 * Formato: enc:v1:<iv_b64url>.<tag_b64url>.<ct_b64url>
 * - iv único de 12 bytes por fila
 * - authTag de 16 bytes
 */
import crypto from 'node:crypto';

const PREFIX = 'enc:v1:';

export function hashLicenseKey(rawKey) {
  const clean = String(rawKey ?? '').trim();
  return crypto.createHash('sha256').update(clean, 'utf8').digest('hex');
}

function deriveKey(sessionSecret) {
  const secret = String(sessionSecret ?? '');
  if (secret.length < 16) {
    throw new Error('SESSION_SECRET ausente o demasiado corto para cifrar licencias');
  }
  const derived = crypto.hkdfSync('sha256', secret, 'stackdock-aes-gcm-v1', 'license-storage', 32);
  return Buffer.from(derived);
}

function toB64url(buffer) {
  return Buffer.from(buffer).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function fromB64url(value) {
  return Buffer.from(String(value).replace(/-/g, '+').replace(/_/g, '/'), 'base64');
}

export function encryptSecret(plainText, sessionSecret) {
  if (plainText === null || plainText === undefined) return null;
  const key = deriveKey(sessionSecret);
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const ciphertext = Buffer.concat([cipher.update(String(plainText), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${PREFIX}${toB64url(iv)}.${toB64url(tag)}.${toB64url(ciphertext)}`;
}

export function decryptSecret(payload, sessionSecret) {
  if (payload === null || payload === undefined || payload === '') return null;
  const raw = String(payload);
  // Compatibilidad con filas legadas en texto plano.
  if (!raw.startsWith(PREFIX)) return raw;

  const key = deriveKey(sessionSecret);
  const parts = raw.slice(PREFIX.length).split('.');
  if (parts.length !== 3) throw new Error('Payload cifrado inválido');
  const [ivPart, tagPart, ctPart] = parts;
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, fromB64url(ivPart));
  decipher.setAuthTag(fromB64url(tagPart));
  const plain = Buffer.concat([decipher.update(fromB64url(ctPart)), decipher.final()]);
  return plain.toString('utf8');
}

/** Descifra sin lanzar (para render del panel). */
export function safeDecrypt(payload, sessionSecret) {
  try {
    return decryptSecret(payload, sessionSecret);
  } catch {
    return null;
  }
}
