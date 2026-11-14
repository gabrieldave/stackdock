/**
 * Google OAuth server-side (authorization code) + sesiones de admin en PostgreSQL.
 * El email se valida SIEMPRE en servidor contra ADMIN_ALLOWED_EMAILS.
 */
import crypto from 'node:crypto';
import { config } from './config.js';
import { query } from './db.js';
import {
  HttpError,
  isHttps,
  parseCookies,
  redirect,
  serializeCookie,
} from './http.js';

export const ADMIN_COOKIE = 'sd_admin';
const STATE_MAX_AGE_MS = 10 * 60 * 1000;

function secret() {
  if (!config.sessionSecret || config.sessionSecret.length < 16) {
    throw new HttpError(503, 'SESSION_SECRET no configurado (mínimo 16 caracteres)');
  }
  return config.sessionSecret;
}

function b64url(buffer) {
  return buffer.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

export function createOAuthState() {
  const payload = `${Date.now()}.${b64url(crypto.randomBytes(16))}`;
  const signature = b64url(crypto.createHmac('sha256', secret()).update(payload).digest());
  return `${b64url(Buffer.from(payload, 'utf8'))}.${signature}`;
}

export function verifyOAuthState(state) {
  const [encoded, signature] = String(state || '').split('.');
  if (!encoded || !signature) return false;
  let payload;
  try {
    payload = Buffer.from(encoded.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8');
  } catch {
    return false;
  }
  const expected = b64url(crypto.createHmac('sha256', secret()).update(payload).digest());
  const left = Buffer.from(signature);
  const right = Buffer.from(expected);
  if (left.length !== right.length || !crypto.timingSafeEqual(left, right)) return false;
  const issuedAt = Number(payload.split('.')[0]);
  return Number.isFinite(issuedAt) && Date.now() - issuedAt <= STATE_MAX_AGE_MS && issuedAt <= Date.now() + 60_000;
}

function callbackUrl() {
  return `${config.publicUrl}/api/auth/callback/google`;
}

function secureCookies(req) {
  return config.publicUrl.startsWith('https://') || isHttps(req);
}

export function handleGoogleStart(req, res) {
  if (!config.googleClientId || !config.googleClientSecret) {
    throw new HttpError(503, 'Google OAuth no configurado');
  }
  const params = new URLSearchParams({
    client_id: config.googleClientId,
    redirect_uri: callbackUrl(),
    response_type: 'code',
    scope: 'openid email profile',
    state: createOAuthState(),
    access_type: 'online',
    prompt: 'select_account',
    include_granted_scopes: 'true',
  });
  redirect(res, `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`);
}

function decodeJwtPayload(token) {
  const parts = String(token || '').split('.');
  if (parts.length !== 3) return null;
  try {
    return JSON.parse(Buffer.from(parts[1].replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8'));
  } catch {
    return null;
  }
}

async function exchangeCode(code) {
  const body = new URLSearchParams({
    code,
    client_id: config.googleClientId,
    client_secret: config.googleClientSecret,
    redirect_uri: callbackUrl(),
    grant_type: 'authorization_code',
  });

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
    body: body.toString(),
    signal: AbortSignal.timeout(10_000),
  });
  if (!response.ok) {
    const detail = await response.text().catch(() => '');
    console.error('[auth] intercambio de código falló:', response.status, detail.slice(0, 200));
    throw new HttpError(502, 'No se pudo completar el inicio de sesión con Google');
  }
  return response.json();
}

async function resolveGoogleEmail(tokens) {
  const claims = decodeJwtPayload(tokens.id_token);
  if (claims) {
    const issuer = String(claims.iss || '');
    const validIssuer = issuer === 'accounts.google.com' || issuer === 'https://accounts.google.com';
    const validAudience = !claims.aud || claims.aud === config.googleClientId;
    if (!validIssuer || !validAudience || (claims.exp && claims.exp * 1000 < Date.now())) {
      throw new HttpError(401, 'Token de Google inválido');
    }
    if (claims.email && claims.email_verified !== false) {
      return String(claims.email);
    }
  }

  if (tokens.access_token) {
    const response = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
      headers: { Authorization: `Bearer ${tokens.access_token}` },
      signal: AbortSignal.timeout(8_000),
    });
    if (response.ok) {
      const profile = await response.json();
      if (profile?.email) return String(profile.email);
    }
  }
  throw new HttpError(401, 'Google no devolvió un email verificado');
}

export async function handleGoogleCallback(req, res, url) {
  const error = url.searchParams.get('error');
  if (error) throw new HttpError(401, `Google OAuth cancelado (${error.slice(0, 40)})`);
  const code = url.searchParams.get('code') || '';
  const state = url.searchParams.get('state') || '';
  if (!code) throw new HttpError(400, 'Código de autorización ausente');
  if (!verifyOAuthState(state)) throw new HttpError(400, 'Estado OAuth inválido o expirado');

  const tokens = await exchangeCode(code);
  const email = String(await resolveGoogleEmail(tokens)).trim().toLowerCase();
  if (!config.adminAllowedEmails.includes(email)) {
    throw new HttpError(403, 'Esta cuenta no tiene acceso al panel');
  }

  const token = crypto.randomBytes(32).toString('base64url');
  const expiresAt = new Date(Date.now() + config.sessionHours * 60 * 60 * 1000);
  await query(`DELETE FROM admin_sessions WHERE expires_at < now()`);
  await query(
    `INSERT INTO admin_sessions (token, email, expires_at) VALUES ($1, $2, $3)`,
    [token, email, expiresAt],
  );

  redirect(res, '/admin', {
    'Set-Cookie': serializeCookie(ADMIN_COOKIE, token, {
      httpOnly: true,
      secure: secureCookies(req),
      sameSite: 'Lax',
      maxAge: config.sessionHours * 60 * 60,
      path: '/',
    }),
  });
}

/** Devuelve el email del admin o null. */
export async function getAdminEmail(req) {
  const token = parseCookies(req)[ADMIN_COOKIE];
  if (!token) return null;
  try {
    const result = await query(
      `SELECT email FROM admin_sessions WHERE token = $1 AND expires_at > now() LIMIT 1`,
      [token],
    );
    return result.rows[0]?.email || null;
  } catch {
    return null;
  }
}

export async function handleLogout(req, res) {
  const token = parseCookies(req)[ADMIN_COOKIE];
  if (token) {
    await query(`DELETE FROM admin_sessions WHERE token = $1`, [token]).catch(() => {});
  }
  redirect(res, '/', {
    'Set-Cookie': serializeCookie(ADMIN_COOKIE, '', {
      httpOnly: true,
      secure: secureCookies(req),
      sameSite: 'Lax',
      maxAge: 0,
      path: '/',
    }),
  });
}
