/**
 * Panel de administración: consultas y acciones 1-clic por `:id`.
 * Licencias cifradas en reposo (AES-256-GCM) y descifradas solo en memoria.
 */
import { config } from './config.js';
import { query } from './db.js';
import { getAdminEmail } from './auth.js';
import { isValidEmail, normalizeEmail, signLicense } from './license.js';
import { encryptSecret, hashLicenseKey, safeDecrypt } from './crypto-store.js';
import { sendLicenseEmail } from './email.js';
import { HttpError, readJsonBody, sendJson } from './http.js';

export function assertSameOrigin(req) {
  const origin = String(req.headers.origin || '').trim();
  if (!origin) return;
  let host;
  try {
    host = new URL(origin).host;
  } catch {
    throw new HttpError(403, 'Origen no permitido');
  }
  const expected = String(req.headers.host || '');
  if (!expected || host !== expected) throw new HttpError(403, 'Origen no permitido');
}

export async function requireAdmin(req) {
  const email = await getAdminEmail(req);
  if (!email) throw new HttpError(401, 'Sesión de admin requerida');
  return email;
}

function canEncrypt() {
  return Boolean(config.sessionSecret && config.sessionSecret.length >= 16);
}

function sealed(value) {
  return canEncrypt() ? encryptSecret(value, config.sessionSecret) : null;
}

function opened(payload, legacyValue) {
  if (payload) {
    const plain = safeDecrypt(payload, config.sessionSecret);
    if (plain) return plain;
  }
  return legacyValue || null;
}

export async function getDashboardData() {
  const [ordersResult, leadsResult, totalsResult, logsResult] = await Promise.all([
    query(
      `SELECT id, created_at, email, plan, add_findaro, amount_cents, currency, status,
              license_key, license_key_enc, license_key_hash, findaro_key, findaro_key_enc, revoked_at
       FROM orders ORDER BY created_at DESC, id DESC LIMIT 100`,
    ),
    query(
      `SELECT id, created_at, email, locale, version, trial_days, source, ip_country
       FROM trial_leads ORDER BY created_at DESC, id DESC LIMIT 100`,
    ),
    query(
      `SELECT COUNT(*)::int AS orders,
              COALESCE(SUM(amount_cents), 0)::int AS revenue_cents,
              COUNT(*) FILTER (WHERE created_at >= now() - interval '30 days')::int AS orders_30d
       FROM orders WHERE status IS DISTINCT FROM 'refunded'`,
    ),
    query(
      `SELECT id, created_at, email, plan, action FROM license_logs
       ORDER BY created_at DESC, id DESC LIMIT 25`,
    ),
  ]);

  const orders = ordersResult.rows.map((order) => ({
    ...order,
    license_key_dec: opened(order.license_key_enc, order.license_key),
    findaro_key_dec: opened(order.findaro_key_enc, order.findaro_key),
  }));

  return {
    orders,
    leads: leadsResult.rows,
    totals: totalsResult.rows[0] || { orders: 0, revenue_cents: 0, orders_30d: 0 },
    logs: logsResult.rows,
  };
}

async function loadOrder(id) {
  const result = await query(
    `SELECT id, email, plan, add_findaro, locale, status, license_key, license_key_enc,
            license_key_hash, findaro_key, findaro_key_enc, amount_cents
     FROM orders WHERE id = $1 LIMIT 1`,
    [id],
  );
  return result.rows[0] || null;
}

function parseOrderId(raw) {
  const id = Number.parseInt(String(raw ?? ''), 10);
  if (!Number.isInteger(id) || id <= 0) throw new HttpError(400, 'id inválido');
  return id;
}

async function persistLicense(order, licenseKey, findaroKey) {
  await query(
    `UPDATE orders
     SET license_key = NULL, findaro_key = NULL,
         license_key_enc = $1, license_key_hash = $2, findaro_key_enc = $3
     WHERE id = $4`,
    [
      sealed(licenseKey),
      hashLicenseKey(licenseKey),
      findaroKey ? sealed(findaroKey) : null,
      order.id,
    ],
  );
}

export async function handleResendLicense(req, res) {
  assertSameOrigin(req);
  await requireAdmin(req);
  const body = await readJsonBody(req);
  return resendOrderById(res, parseOrderId(body.orderId ?? body.id));
}

export async function handleResendOrderById(req, res, id) {
  assertSameOrigin(req);
  await requireAdmin(req);
  return resendOrderById(res, parseOrderId(id));
}

async function resendOrderById(res, orderId) {
  const order = await loadOrder(orderId);
  if (!order) throw new HttpError(404, 'Orden no encontrada');

  const email = normalizeEmail(order.email);
  if (!isValidEmail(email)) throw new HttpError(400, 'La orden no tiene un email válido');
  const plan = order.plan === 'personal' ? 'personal' : 'pro';

  let licenseKey = opened(order.license_key_enc, order.license_key);
  let findaroKey = opened(order.findaro_key_enc, order.findaro_key) || '';

  if (!licenseKey) {
    licenseKey = signLicense(email, plan);
  }
  if (order.add_findaro && !findaroKey) {
    findaroKey = signLicense(email, 'findaro');
  }
  if (!order.license_key_enc || !order.license_key_hash) {
    await persistLicense(order, licenseKey, findaroKey || null);
    await query(
      `INSERT INTO license_logs (email, plan, order_id, action) VALUES ($1, $2, $3, 'issued')`,
      [email, plan, order.id],
    );
  }

  const mail = await sendLicenseEmail({
    email,
    plan,
    licenseKey,
    findaroKey,
    locale: order.locale === 'es' ? 'es' : 'en',
  });
  if (!mail.ok) {
    throw new HttpError(502, `No se pudo enviar el email: ${mail.error || 'error de Resend'}`);
  }

  await query(
    `INSERT INTO license_logs (email, plan, order_id, action) VALUES ($1, $2, $3, 'resent')`,
    [email, plan, order.id],
  );

  sendJson(res, 200, { ok: true, email, plan });
}

export async function handleIssueLicense(req, res) {
  assertSameOrigin(req);
  const adminEmail = await requireAdmin(req);
  const body = await readJsonBody(req);
  const email = normalizeEmail(body.email);
  if (!isValidEmail(email)) throw new HttpError(400, 'Email inválido');
  const plan = String(body.plan || '').toLowerCase();
  if (plan !== 'personal' && plan !== 'pro') throw new HttpError(400, 'Plan inválido (personal o pro)');

  const licenseKey = signLicense(email, plan);
  const inserted = await query(
    `INSERT INTO orders (email, plan, add_findaro, amount_cents, currency, status,
                         license_key, license_key_enc, license_key_hash, locale, raw)
     VALUES ($1, $2, false, 0, $3, 'manual', NULL, $4, $5, $6, $7::jsonb)
     RETURNING id, created_at`,
    [
      email,
      plan,
      'usd',
      sealed(licenseKey),
      hashLicenseKey(licenseKey),
      String(body.locale || '').toLowerCase() === 'es' ? 'es' : 'en',
      JSON.stringify({ source: 'admin', admin: adminEmail }),
    ],
  );
  const order = inserted.rows[0];

  await query(
    `INSERT INTO license_logs (email, plan, order_id, action) VALUES ($1, $2, $3, 'manual_issued')`,
    [email, plan, order.id],
  );

  // La clave completa se devuelve una sola vez al admin que la emitió.
  sendJson(res, 200, { ok: true, id: order.id, email, plan, licenseKey });
}

/** Revocar ⇄ Reactivar (1-clic por id). */
export async function handleToggleRevoke(req, res, id) {
  assertSameOrigin(req);
  await requireAdmin(req);
  const orderId = parseOrderId(id);
  const order = await loadOrder(orderId);
  if (!order) throw new HttpError(404, 'Orden no encontrada');

  const revoking = order.status !== 'revoked';
  const nextStatus = revoking ? 'revoked' : (Number(order.amount_cents) > 0 ? 'paid' : 'manual');

  await query(
    `UPDATE orders SET status = $1, revoked_at = CASE WHEN $2 THEN now() ELSE NULL END WHERE id = $3`,
    [nextStatus, revoking, orderId],
  );

  if (revoking && order.license_key_hash) {
    await query(`DELETE FROM license_activations WHERE license_hash = $1`, [order.license_key_hash]);
  }

  await query(
    `INSERT INTO license_logs (email, plan, order_id, action) VALUES ($1, $2, $3, $4)`,
    [order.email, order.plan, orderId, revoking ? 'revoked' : 'reactivated'],
  );

  sendJson(res, 200, { ok: true, id: orderId, status: nextStatus });
}

/** Eliminar orden (1-clic por id). */
export async function handleDeleteOrder(req, res, id) {
  assertSameOrigin(req);
  await requireAdmin(req);
  const orderId = parseOrderId(id);
  const order = await loadOrder(orderId);
  if (!order) throw new HttpError(404, 'Orden no encontrada');

  await query(`DELETE FROM orders WHERE id = $1`, [orderId]);
  await query(
    `INSERT INTO license_logs (email, plan, order_id, action) VALUES ($1, $2, $3, 'deleted')`,
    [order.email, order.plan, null],
  );

  sendJson(res, 200, { ok: true, id: orderId, deleted: true });
}

export function adminAllowedList() {
  return [...config.adminAllowedEmails];
}
