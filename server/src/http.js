/**
 * Utilidades HTTP sin frameworks: cabeceras de seguridad, cookies, JSON con límite,
 * errores tipados y escape HTML.
 */
import { config } from './config.js';

export const CONTENT_SECURITY_POLICY = [
  "default-src 'self'",
  "script-src 'self' 'unsafe-inline' https://www.googletagmanager.com",
  "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
  "font-src 'self' https://fonts.gstatic.com data:",
  "img-src 'self' data: blob: https:",
  "media-src 'self' https:",
  "frame-src https://www.youtube-nocookie.com https://www.youtube.com",
  "connect-src 'self' https:",
  "base-uri 'self'",
  "frame-ancestors 'none'",
  "form-action 'self'",
  "object-src 'none'",
].join('; ');

export class HttpError extends Error {
  constructor(statusCode, message, headers = {}) {
    super(message);
    this.name = 'HttpError';
    this.statusCode = statusCode;
    this.headers = headers;
  }
}

export function applySecurityHeaders(res) {
  res.setHeader('Content-Security-Policy', CONTENT_SECURITY_POLICY);
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
}

export function sendJson(res, statusCode, payload, extraHeaders = {}) {
  if (res.headersSent) return;
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
    ...extraHeaders,
  });
  res.end(body);
}

export function sendText(res, statusCode, text, extraHeaders = {}) {
  if (res.headersSent) return;
  const body = Buffer.from(String(text), 'utf8');
  res.writeHead(statusCode, {
    'Content-Type': 'text/plain; charset=utf-8',
    'Content-Length': body.length,
    ...extraHeaders,
  });
  res.end(body);
}

export function sendHtml(res, statusCode, html, extraHeaders = {}) {
  if (res.headersSent) return;
  const body = Buffer.from(String(html), 'utf8');
  res.writeHead(statusCode, {
    'Content-Type': 'text/html; charset=utf-8',
    'Content-Length': body.length,
    'Cache-Control': 'no-store',
    ...extraHeaders,
  });
  res.end(body);
}

export function redirect(res, location, extraHeaders = {}) {
  if (res.headersSent) return;
  res.writeHead(302, {
    Location: location,
    'Cache-Control': 'no-store',
    ...extraHeaders,
  });
  res.end();
}

export function parseCookies(req) {
  const header = String(req?.headers?.cookie || '');
  const cookies = {};
  for (const part of header.split(';')) {
    const index = part.indexOf('=');
    if (index === -1) continue;
    const name = part.slice(0, index).trim();
    if (!name || Object.prototype.hasOwnProperty.call(cookies, name)) continue;
    try {
      cookies[name] = decodeURIComponent(part.slice(index + 1).trim());
    } catch {
      cookies[name] = part.slice(index + 1).trim();
    }
  }
  return cookies;
}

export function serializeCookie(name, value, options = {}) {
  const parts = [`${name}=${encodeURIComponent(value)}`];
  parts.push(`Path=${options.path || '/'}`);
  if (options.maxAge !== undefined) parts.push(`Max-Age=${Math.floor(options.maxAge)}`);
  if (options.expires) parts.push(`Expires=${options.expires.toUTCString()}`);
  parts.push(`SameSite=${options.sameSite || 'Lax'}`);
  if (options.httpOnly) parts.push('HttpOnly');
  if (options.secure) parts.push('Secure');
  return parts.join('; ');
}

export function isHttps(req) {
  const proto = String(req?.headers?.['x-forwarded-proto'] || '').split(',')[0].trim().toLowerCase();
  if (proto) return proto === 'https';
  return Boolean(req?.socket?.encrypted);
}

export function getClientIp(req) {
  const forwarded = String(req?.headers?.['x-forwarded-for'] || '').split(',')[0].trim();
  if (forwarded) return forwarded;
  return String(req?.socket?.remoteAddress || 'unknown');
}

/** Lee y parsea JSON con límite estricto (64KB por defecto). */
export function readJsonBody(req, limit = config.jsonLimitBytes) {
  return new Promise((resolve, reject) => {
    if (req.method === 'GET' || req.method === 'HEAD') {
      reject(new HttpError(400, 'Cuerpo JSON requerido'));
      return;
    }
    const chunks = [];
    let size = 0;
    let settled = false;

    const fail = (error) => {
      if (settled) return;
      settled = true;
      reject(error);
    };

    req.on('data', (chunk) => {
      if (settled) return;
      size += chunk.length;
      if (size > limit) {
        // Se rechaza con 413 sin destruir el socket: se drena el resto para
        // poder responder y mantener la conexión en estado consistente.
        settled = true;
        reject(new HttpError(413, 'Cuerpo demasiado grande'));
        req.resume();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (settled) return;
      settled = true;
      const raw = Buffer.concat(chunks).toString('utf8').trim();
      if (!raw) {
        resolve({});
        return;
      }
      try {
        const parsed = JSON.parse(raw);
        if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
          reject(new HttpError(400, 'JSON inválido'));
          return;
        }
        resolve(parsed);
      } catch {
        reject(new HttpError(400, 'JSON inválido'));
      }
    });
    req.on('error', (error) => fail(new HttpError(400, error.message || 'Error leyendo cuerpo')));
  });
}

/** Lee el cuerpo crudo (necesario para verificar firmas). */
export function readRawBody(req, limit = 512 * 1024) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    let settled = false;
    const fail = (error) => {
      if (settled) return;
      settled = true;
      reject(error);
    };
    req.on('data', (chunk) => {
      if (settled) return;
      size += chunk.length;
      if (size > limit) {
        // Se rechaza con 413 sin destruir el socket: se drena el resto para
        // poder responder y mantener la conexión en estado consistente.
        settled = true;
        reject(new HttpError(413, 'Cuerpo demasiado grande'));
        req.resume();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (settled) return;
      settled = true;
      resolve(Buffer.concat(chunks));
    });
    req.on('error', (error) => fail(new HttpError(400, error.message || 'Error leyendo cuerpo')));
  });
}

const HTML_ESCAPES = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#39;',
};

export function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (char) => HTML_ESCAPES[char]);
}

export function methodNotAllowed(res, allow) {
  sendJson(res, 405, { error: 'Método no permitido' }, { Allow: allow });
}
