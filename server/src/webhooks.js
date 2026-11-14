/**
 * Webhooks de pago (Stripe directo o reenvío desde n8n).
 * - Firma Stripe-Signature sobre cuerpo crudo (tolerancia 300 s).
 * - Idempotencia por stripe_event_id / stripe_session_id / stripe_payment_intent.
 * - Licencias cifradas en reposo (AES-256-GCM) y hash para control de asientos.
 * - Reembolsos y disputas revocan automáticamente el acceso.
 */
import crypto from 'node:crypto';
import { config } from './config.js';
import { query } from './db.js';
import { normalizeEmail, signLicense } from './license.js';
import { encryptSecret, hashLicenseKey } from './crypto-store.js';
import { sendLicenseEmail } from './email.js';
import { HttpError, readRawBody, sendJson } from './http.js';

const TOLERANCE_SECONDS = 300;
const CHECKOUT_EVENTS = new Set(['checkout.session.completed']);
const REVOKE_EVENTS = new Set(['charge.refunded', 'charge.dispute.created', 'payment_intent.canceled']);

/** Estado resultante para un evento de revocación (puro/testeable). */
export function revokedStatusForEvent(type) {
  if (type === 'charge.dispute.created') return 'revoked';
  if (type === 'charge.refunded' || type === 'payment_intent.canceled') return 'refunded';
  return null;
}

function parseSignatureHeader(header) {
  const parts = String(header || '').split(',').map((part) => part.trim());
  const parsed = { t: '', v1: [] };
  for (const part of parts) {
    const index = part.indexOf('=');
    if (index === -1) continue;
    const key = part.slice(0, index);
    const value = part.slice(index + 1);
    if (key === 't') parsed.t = value;
    if (key === 'v1') parsed.v1.push(value);
  }
  return parsed;
}

function hmacHex(secret, signedPayload) {
  return crypto.createHmac('sha256', secret).update(signedPayload, 'utf8').digest('hex');
}

function safeEqualHex(a, b) {
  const left = Buffer.from(String(a), 'utf8');
  const right = Buffer.from(String(b), 'utf8');
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}

export function verifyStripeSignature(rawBody, header, secret = config.stripeWebhookSecret) {
  if (!secret) throw new HttpError(503, 'Webhook de pagos no configurado');
  const { t, v1 } = parseSignatureHeader(header);
  if (!t || v1.length === 0) throw new HttpError(400, 'Firma de webhook inválida');

  const timestamp = Number(t);
  if (!Number.isFinite(timestamp)) throw new HttpError(400, 'Firma de webhook inválida');
  if (Math.abs(Date.now() / 1000 - timestamp) > TOLERANCE_SECONDS) {
    throw new HttpError(400, 'Firma de webhook expirada');
  }

  const signedPayload = `${t}.${rawBody.toString('utf8')}`;
  const candidates = [secret];
  if (secret.startsWith('whsec_')) {
    // Compatibilidad con flujos n8n que decodifican el secreto en base64.
    candidates.push(Buffer.from(secret.slice(6), 'base64'));
  }
  const valid = candidates.some((candidate) => v1.some((signature) => safeEqualHex(hmacHex(candidate, signedPayload), signature)));
  if (!valid) throw new HttpError(400, 'Firma de webhook inválida');
  return true;
}

function sealed(value) {
  if (!value) return null;
  if (!config.sessionSecret || config.sessionSecret.length < 16) {
    throw new HttpError(503, 'SESSION_SECRET no configurado para cifrar licencias');
  }
  return encryptSecret(value, config.sessionSecret);
}

function inferPlan(session) {
  const meta = session?.metadata || {};
  const amount = Number(session?.amount_total ?? session?.amount_subtotal ?? 0);
  let plan = String(meta.plan || '').toLowerCase();
  let addFindaro = meta.addFindaro === true || meta.addFindaro === 'true' || meta.addFindaro === '1';

  if (plan !== 'personal' && plan !== 'pro') {
    plan = amount >= 4800 ? 'pro' : amount >= 1900 ? 'pro' : 'personal';
    if (amount >= 4800) addFindaro = true;
  }
  if (plan === 'personal') addFindaro = false;

  return { plan, addFindaro, amount };
}

function paymentIntentId(value) {
  if (!value) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'object' && value.id) return String(value.id);
  return '';
}

async function upsertOrder({ session, eventId, email, plan, addFindaro, amount, locale }) {
  const result = await query(
    `INSERT INTO orders
       (email, plan, add_findaro, amount_cents, currency, stripe_session_id, stripe_event_id,
        stripe_payment_intent, status, locale, raw)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb)
     ON CONFLICT DO NOTHING
     RETURNING id, license_key_enc, findaro_key_enc, status`,
    [
      email || null,
      plan,
      addFindaro,
      Number.isFinite(amount) ? amount : null,
      String(session?.currency || 'usd').toLowerCase(),
      session?.id || null,
      eventId,
      paymentIntentId(session?.payment_intent) || null,
      'paid',
      locale || null,
      JSON.stringify(session ?? {}),
    ],
  );
  if (result.rows[0]) return { order: result.rows[0], duplicate: false };

  const existing = await query(
    `SELECT id, license_key_enc, findaro_key_enc, status FROM orders
     WHERE stripe_event_id = $1 OR stripe_session_id = $2
     ORDER BY id LIMIT 1`,
    [eventId, session?.id || ''],
  );
  return { order: existing.rows[0] || null, duplicate: true };
}

async function handleCheckoutCompleted(event, res) {
  const session = event?.data?.object || {};
  const paymentStatus = String(session.payment_status || '');
  if (paymentStatus && paymentStatus !== 'paid' && paymentStatus !== 'no_payment_required') {
    sendJson(res, 200, { received: true, pending: true });
    return;
  }

  const eventId = String(event?.id || `session:${session.id || crypto.randomUUID()}`);
  const { plan, addFindaro, amount } = inferPlan(session);
  const locale = String(session?.metadata?.locale || 'en') === 'es' ? 'es' : 'en';
  const email = normalizeEmail(
    session?.customer_details?.email || session?.customer_email || session?.metadata?.customer_email || '',
  );

  const { order, duplicate } = await upsertOrder({ session, eventId, email, plan, addFindaro, amount, locale });
  if (!order) {
    console.error('[webhook] orden no persistida para evento', eventId);
    sendJson(res, 500, { error: 'No se pudo registrar la orden' });
    return;
  }

  if (!email || order.license_key_enc) {
    sendJson(res, 200, { received: true, duplicate: duplicate || undefined, license: Boolean(order.license_key_enc) });
    return;
  }

  let licenseKey;
  try {
    licenseKey = signLicense(email, plan);
  } catch (error) {
    console.error('[webhook] no se pudo firmar la licencia:', error.message);
    sendJson(res, 503, { error: 'Emisión de licencias no configurada' });
    return;
  }
  const findaroKey = addFindaro ? signLicense(email, 'findaro') : null;

  try {
    await query(
      `UPDATE orders
       SET license_key = NULL, findaro_key = NULL,
           license_key_enc = $1, license_key_hash = $2, findaro_key_enc = $3
       WHERE id = $4`,
      [sealed(licenseKey), hashLicenseKey(licenseKey), findaroKey ? sealed(findaroKey) : null, order.id],
    );
  } catch (error) {
    console.error('[webhook] cifrado de licencia falló:', error.message);
    sendJson(res, 503, { error: 'Almacenamiento seguro no configurado' });
    return;
  }

  await query(
    `INSERT INTO license_logs (email, plan, order_id, action) VALUES ($1, $2, $3, 'issued')`,
    [email, plan, order.id],
  );

  const mail = await sendLicenseEmail({
    email,
    plan,
    licenseKey,
    findaroKey: findaroKey || '',
    locale,
  });
  if (mail.ok) {
    await query(
      `INSERT INTO license_logs (email, plan, order_id, action) VALUES ($1, $2, $3, 'email_sent')`,
      [email, plan, order.id],
    );
  }

  sendJson(res, 200, { received: true, duplicate: duplicate || undefined, license: true });
}

async function findOrderForRevocation(object) {
  const intent = paymentIntentId(object?.payment_intent);
  const sessionId = String(object?.metadata?.checkout_session_id || object?.id || '').startsWith('cs_')
    ? String(object.id)
    : '';
  const email = normalizeEmail(
    object?.billing_details?.email || object?.receipt_email || object?.customer_email || object?.metadata?.customer_email || '',
  );

  const result = await query(
    `SELECT id, email, plan, status, license_key_hash
     FROM orders
     WHERE ($1 <> '' AND stripe_payment_intent = $1)
        OR ($2 <> '' AND stripe_session_id = $2)
        OR ($3 <> '' AND lower(email) = lower($3))
     ORDER BY id DESC
     LIMIT 1`,
    [intent, sessionId, email],
  );
  return result.rows[0] || null;
}

async function handleRevocation(event, res) {
  const object = event?.data?.object || {};
  const order = await findOrderForRevocation(object);
  if (!order) {
    sendJson(res, 200, { received: true, matched: false });
    return;
  }

  const nextStatus = revokedStatusForEvent(event.type) || 'refunded';
  if (order.status === nextStatus) {
    sendJson(res, 200, { received: true, matched: true, duplicate: true });
    return;
  }

  await query(
    `UPDATE orders SET status = $1, revoked_at = now() WHERE id = $2`,
    [nextStatus, order.id],
  );
  if (order.license_key_hash) {
    await query(`DELETE FROM license_activations WHERE license_hash = $1`, [order.license_key_hash]);
  }

  const action = event.type === 'charge.dispute.created' ? 'auto_revoked_dispute' : 'auto_revoked_refund';
  const already = await query(
    `SELECT 1 FROM license_logs WHERE order_id = $1 AND action = $2 LIMIT 1`,
    [order.id, action],
  );
  if (!already.rows[0]) {
    await query(
      `INSERT INTO license_logs (email, plan, order_id, action) VALUES ($1, $2, $3, $4)`,
      [order.email, order.plan, order.id, action],
    );
  }

  sendJson(res, 200, { received: true, matched: true, status: nextStatus });
}

export async function handlePaymentWebhook(req, res) {
  if (!config.stripeWebhookSecret) throw new HttpError(503, 'Webhook de pagos no configurado');
  const raw = await readRawBody(req);
  verifyStripeSignature(raw, req.headers['stripe-signature']);

  let event;
  try {
    event = JSON.parse(raw.toString('utf8'));
  } catch {
    throw new HttpError(400, 'Cuerpo de webhook inválido');
  }

  const type = String(event?.type || '');
  if (!type) throw new HttpError(400, 'Evento sin tipo');

  if (CHECKOUT_EVENTS.has(type)) {
    await handleCheckoutCompleted(event, res);
    return;
  }
  if (REVOKE_EVENTS.has(type)) {
    await handleRevocation(event, res);
    return;
  }

  sendJson(res, 200, { received: true, ignored: true });
}
