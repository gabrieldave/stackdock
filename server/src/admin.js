/**
 * Panel de administración: consultas y acciones (reenviar / emitir licencia).
 * Toda la autorización se valida en servidor; ninguna regla vive solo en el cliente.
 */
import { config } from './config.js';
import { query } from './db.js';
import { getAdminEmail } from './auth.js';
import { isValidEmail, normalizeEmail, signLicense } from './license.js';
import { sendLicenseEmail } from './email.js';
import { HttpError, readJsonBody, sendJson } from './http.js';

function assertSameOrigin(req) {
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

export async function getDashboardData() {
  const [ordersResult, leadsResult, totalsResult, logsResult] = await Promise.all([
    query(
      `SELECT id, created_at, email, plan, add_findaro, amount_cents, currency, status, license_key, findaro_key
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

  return {
    orders: ordersResult.rows,
    leads: leadsResult.rows,
    totals: totalsResult.rows[0] || { orders: 0, revenue_cents: 0, orders_30d: 0 },
    logs: logsResult.rows,
  };
}

export async function handleResendLicense(req, res) {
  assertSameOrigin(req);
  await requireAdmin(req);
  const body = await readJsonBody(req);
  const orderId = Number.parseInt(String(body.orderId ?? ''), 10);
  if (!Number.isInteger(orderId) || orderId <= 0) throw new HttpError(400, 'orderId inválido');

  const result = await query(
    `SELECT id, email, plan, add_findaro, locale, license_key, findaro_key FROM orders WHERE id = $1 LIMIT 1`,
    [orderId],
  );
  const order = result.rows[0];
  if (!order) throw new HttpError(404, 'Orden no encontrada');

  const email = normalizeEmail(order.email);
  if (!isValidEmail(email)) throw new HttpError(400, 'La orden no tiene un email válido');
  const plan = order.plan === 'personal' ? 'personal' : 'pro';

  let licenseKey = order.license_key;
  if (!licenseKey) {
    licenseKey = signLicense(email, plan);
    await query(`UPDATE orders SET license_key = $1 WHERE id = $2`, [licenseKey, order.id]);
    await query(
      `INSERT INTO license_logs (email, plan, order_id, action) VALUES ($1, $2, $3, 'issued')`,
      [email, plan, order.id],
    );
  }

  let findaroKey = order.findaro_key || '';
  if (order.add_findaro && !findaroKey) {
    findaroKey = signLicense(email, 'findaro');
    await query(`UPDATE orders SET findaro_key = $1 WHERE id = $2`, [findaroKey, order.id]);
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
    `INSERT INTO orders (email, plan, add_findaro, amount_cents, currency, status, license_key, locale, raw)
     VALUES ($1, $2, false, 0, $3, 'manual', $4, $5, $6::jsonb)
     RETURNING id, created_at`,
    [
      email,
      plan,
      'usd',
      licenseKey,
      String(body.locale || '').toLowerCase() === 'es' ? 'es' : 'en',
      JSON.stringify({ source: 'admin', admin: adminEmail }),
    ],
  );
  const order = inserted.rows[0];

  await query(
    `INSERT INTO license_logs (email, plan, order_id, action) VALUES ($1, $2, $3, 'manual_issued')`,
    [email, plan, order.id],
  );

  sendJson(res, 200, { ok: true, id: order.id, email, plan, licenseKey });
}

export function adminAllowedList() {
  return [...config.adminAllowedEmails];
}
