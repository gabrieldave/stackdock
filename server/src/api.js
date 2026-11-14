/**
 * Handlers de API: health (con DB), trial, trial/sync, license/activate y checkout.
 * Rate limiting: 10 intentos / 15 minutos por IP en trial y licencias.
 */
import { config } from './config.js';
import { query } from './db.js';
import { isValidEmail, normalizeEmail, publicKeyFromPrivate, verifyLicense } from './license.js';
import { hashLicenseKey } from './crypto-store.js';
import { resolveLocale } from './geo.js';
import { computeQuote, buildPaymentPayload } from './pricing.js';
import { createCheckoutSession, notifyTrialLead } from './n8n.js';
import { createStripeCheckout } from './stripe.js';
import { HttpError, getClientIp, readJsonBody, sendJson } from './http.js';
import { createRateLimiter } from './rate-limit.js';

const limiter = createRateLimiter(config.rateLimit);

/** 10 intentos por ventana de 15 minutos (config.rateLimit). */
function enforceRate(req, res) {
  const outcome = limiter.check(getClientIp(req));
  if (outcome.limited) {
    res.setHeader('Retry-After', String(outcome.retryAfter));
    throw new HttpError(429, 'Demasiados intentos. Inténtalo más tarde.');
  }
}

/**
 * Decisión pura de asientos por plan (testeable sin BD).
 * Personal = 1 Mac · Pro = 3 Macs · misma Mac siempre idempotente.
 */
export function seatDecision({ plan, existingDevice, devicesUsed }) {
  const seats = plan === 'personal' ? 1 : 3;
  if (existingDevice) return { allowed: true, reason: 'same_device', seats };
  if (devicesUsed >= seats) return { allowed: false, reason: 'seat_limit_exceeded', seats };
  return { allowed: true, reason: 'new_device', seats };
}

/** deviceId determinista del cliente: SHA-256 hex de 64 caracteres. */
function isValidDeviceId(value) {
  return /^[a-f0-9]{64}$/.test(String(value || '').toLowerCase());
}

export async function handleHealth(req, res) {
  if (!config.databaseUrl) {
    sendJson(res, 200, { status: 'ok', version: config.version, db: false });
    return;
  }
  try {
    await query('SELECT 1');
    sendJson(res, 200, { status: 'ok', version: config.version, db: true });
  } catch (error) {
    console.error('[health] DB inaccesible:', error.message);
    sendJson(res, 503, { status: 'degraded', version: config.version, db: false });
  }
}

export async function handleTrial(req, res) {
  enforceRate(req, res);

  const body = await readJsonBody(req);
  const email = normalizeEmail(body.email);
  if (!isValidEmail(email)) throw new HttpError(400, 'Email inválido');

  const geo = resolveLocale(req);
  const locale = body.locale === 'es' || body.locale === 'en' ? body.locale : geo.locale;
  const version = String(body.version || config.version).trim().slice(0, 32) || config.version;
  const source = String(body.source || 'stackdock-web').trim().slice(0, 64) || 'stackdock-web';
  const trialDays = 14;

  await query(
    `INSERT INTO trial_leads (email, locale, version, trial_days, source, ip_country)
     VALUES ($1, $2, $3, $4, $5, $6)
     ON CONFLICT (email) DO UPDATE SET
       locale = EXCLUDED.locale,
       version = EXCLUDED.version,
       trial_days = EXCLUDED.trial_days,
       source = EXCLUDED.source,
       ip_country = EXCLUDED.ip_country`,
    [email, locale, version, trialDays, source, geo.country || null],
  );

  notifyTrialLead({ email, locale, version, trialDays, source, country: geo.country });
  sendJson(res, 200, { ok: true });
}

/** Ancla remota del trial: hardware_trials (deviceId determinista). */
export async function handleTrialSync(req, res) {
  enforceRate(req, res);

  const body = await readJsonBody(req);
  const deviceId = String(body.deviceId || '').toLowerCase();
  if (!isValidDeviceId(deviceId)) throw new HttpError(400, 'deviceId inválido');

  const localFirst = Number(body.localFirstLaunch);
  const nowSeconds = Date.now() / 1000;
  const candidate = Number.isFinite(localFirst) && localFirst > 0 ? Math.min(localFirst, nowSeconds) : nowSeconds;
  const version = String(body.version || config.version).trim().slice(0, 32) || config.version;
  const geo = resolveLocale(req);

  const result = await query(
    `INSERT INTO hardware_trials (device_id, first_seen_at, last_seen_at, app_version, ip_country)
     VALUES ($1, to_timestamp($2), now(), $3, $4)
     ON CONFLICT (device_id) DO UPDATE SET
       last_seen_at = now(),
       app_version = EXCLUDED.app_version
     RETURNING EXTRACT(EPOCH FROM first_seen_at)::double precision AS first_epoch,
               EXTRACT(EPOCH FROM now())::double precision AS now_epoch`,
    [deviceId, candidate, version, geo.country || null],
  );

  const row = result.rows[0] || {};
  sendJson(res, 200, {
    ok: true,
    serverFirstSeenEpoch: Number(row.first_epoch) || candidate,
    serverNowEpoch: Number(row.now_epoch) || nowSeconds,
  });
}

/** Verifica la firma Ed25519 en servidor y determina el plan. */
function planFromLicense(email, licenseKey) {
  let publicKey;
  try {
    publicKey = publicKeyFromPrivate();
  } catch {
    throw new HttpError(503, 'Emisión de licencias no configurada');
  }
  for (const plan of ['pro', 'personal']) {
    if (verifyLicense(licenseKey, email, plan, publicKey)) return plan;
  }
  return null;
}

/** Control de asientos (Personal 1 Mac / Pro 3 Macs) + revocación. */
export async function handleLicenseActivate(req, res) {
  enforceRate(req, res);

  const body = await readJsonBody(req);
  const email = normalizeEmail(body.email);
  const licenseKey = String(body.licenseKey || '').trim();
  const deviceId = String(body.deviceId || '').toLowerCase();
  const version = String(body.version || config.version).trim().slice(0, 32) || config.version;

  if (!isValidEmail(email)) throw new HttpError(400, 'Email inválido');
  if (!/^SDOCK-[A-Za-z0-9_-]{40,}$/.test(licenseKey)) throw new HttpError(400, 'licenseKey inválida');
  if (!isValidDeviceId(deviceId)) throw new HttpError(400, 'deviceId inválido');

  const plan = planFromLicense(email, licenseKey);
  if (!plan) throw new HttpError(400, 'Firma Ed25519 inválida');

  const licenseHash = hashLicenseKey(licenseKey);
  const seats = plan === 'personal' ? 1 : 3;

  const orderResult = await query(
    `SELECT id, status FROM orders WHERE license_key_hash = $1 ORDER BY id DESC LIMIT 1`,
    [licenseHash],
  );
  const order = orderResult.rows[0] || null;
  if (order && (order.status === 'revoked' || order.status === 'refunded')) {
    sendJson(res, 403, { ok: false, reason: 'revoked' });
    return;
  }

  const existing = await query(
    `SELECT id FROM license_activations WHERE license_hash = $1 AND device_id = $2 LIMIT 1`,
    [licenseHash, deviceId],
  );

  if (existing.rows[0]) {
    await query(
      `UPDATE license_activations SET last_seen_at = now(), app_version = $1 WHERE id = $2`,
      [version, existing.rows[0].id],
    );
    const count = await query(
      `SELECT COUNT(*)::int AS devices FROM license_activations WHERE license_hash = $1`,
      [licenseHash],
    );
    sendJson(res, 200, { ok: true, plan, seats, devices: count.rows[0]?.devices ?? 1 });
    return;
  }

  const count = await query(
    `SELECT COUNT(*)::int AS devices FROM license_activations WHERE license_hash = $1`,
    [licenseHash],
  );
  const devices = count.rows[0]?.devices ?? 0;
  const decision = seatDecision({ plan, existingDevice: false, devicesUsed: devices });
  if (!decision.allowed) {
    sendJson(res, 403, { ok: false, reason: decision.reason, seats, devices });
    return;
  }

  await query(
    `INSERT INTO license_activations (license_hash, order_id, email, plan, device_id, app_version)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [licenseHash, order?.id ?? null, email, plan, deviceId, version],
  );

  sendJson(res, 200, { ok: true, plan, seats, devices: devices + 1 });
}

export async function handleCheckout(req, res) {
  const body = await readJsonBody(req);
  const quote = computeQuote(body);

  const payload = buildPaymentPayload(quote, {
    addFindaro: quote.addFindaro,
    locale: quote.locale,
    customer_email: quote.customerEmail || '',
    source: 'stackdock-server',
  });

  let url;
  try {
    url = await createCheckoutSession(payload);
  } catch (gatewayError) {
    // La pasarela universal (n8n) aún no mapea appId "stackdock": usamos la API
    // oficial de Stripe con la misma cotización exacta (Personal 9.99 / Pro 19 / +Findaro 29).
    if (!config.stripeSecretKey) throw gatewayError;
    console.warn('[checkout] pasarela n8n no disponible, usando Stripe directo:', gatewayError.message);
    url = await createStripeCheckout(quote);
  }
  sendJson(res, 200, { url });
}
