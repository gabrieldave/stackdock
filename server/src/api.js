/**
 * Handlers de API: health, trial, checkout.
 */
import { config } from './config.js';
import { query } from './db.js';
import { isValidEmail, normalizeEmail } from './license.js';
import { resolveLocale } from './geo.js';
import { computeQuote, buildPaymentPayload } from './pricing.js';
import { createCheckoutSession, notifyTrialLead } from './n8n.js';
import { createStripeCheckout } from './stripe.js';
import { HttpError, getClientIp, readJsonBody, sendJson } from './http.js';

const trialHits = new Map();

function rateLimited(ip) {
  const now = Date.now();
  const windowStart = now - config.trialRateLimit.windowMs;
  const hits = (trialHits.get(ip) || []).filter((ts) => ts > windowStart);
  if (hits.length >= config.trialRateLimit.max) {
    trialHits.set(ip, hits);
    return true;
  }
  hits.push(now);
  trialHits.set(ip, hits);
  if (trialHits.size > 5_000) {
    for (const [key, timestamps] of trialHits) {
      if (!timestamps.some((ts) => ts > windowStart)) trialHits.delete(key);
    }
  }
  return false;
}

export function handleHealth(req, res) {
  sendJson(res, 200, { status: 'ok', version: config.version });
}

export async function handleTrial(req, res) {
  const ip = getClientIp(req);
  if (rateLimited(ip)) {
    throw new HttpError(429, 'Demasiadas solicitudes. Inténtalo más tarde.');
  }

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
