/**
 * Webhooks salientes a n8n. Timeouts cortos y validación HTTPS del destino devuelto.
 */
import { config } from './config.js';
import { normalizeEmail } from './license.js';

export function isHttpsUrl(value) {
  try {
    const url = new URL(String(value));
    return url.protocol === 'https:';
  } catch {
    return false;
  }
}

async function postJson(url, payload, timeoutMs) {
  if (!url) throw new Error('Webhook no configurado');
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      'User-Agent': `StackDock-Server/${config.version}`,
    },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(timeoutMs),
  });
  const text = await response.text();
  return { status: response.status, ok: response.ok, text };
}

/** Fire-and-forget: el trial nunca bloquea la descarga. */
export function notifyTrialLead(lead) {
  if (!config.trialWebhookUrl) return;
  const payload = {
    event: 'stackdock.trial.lead',
    email: normalizeEmail(lead.email),
    locale: lead.locale,
    lang: lead.locale,
    product: 'stackdock',
    version: lead.version,
    trial_days: lead.trialDays,
    source: lead.source,
    ip_country: lead.country,
    ts: new Date().toISOString(),
  };
  postJson(config.trialWebhookUrl, payload, 5_000)
    .then(({ ok, status }) => {
      if (!ok) console.warn('[n8n] trial webhook respondió', status);
    })
    .catch((error) => {
      console.warn('[n8n] trial webhook no disponible:', error.message);
    });
}

/**
 * Llama al Payment Gateway Universal (n8n) y devuelve la URL de checkout.
 * La moneda base es usd y NUNCA se envían currency_options.
 */
export async function createCheckoutSession(payload) {
  if (!config.paymentWebhookUrl) {
    const error = new Error('Pasarela de pago no configurada');
    error.statusCode = 502;
    throw error;
  }
  let result;
  try {
    result = await postJson(config.paymentWebhookUrl, payload, 15_000);
  } catch (error) {
    const wrapped = new Error(`Pasarela de pago no disponible: ${error.message}`);
    wrapped.statusCode = 502;
    throw wrapped;
  }

  if (!result.ok) {
    const wrapped = new Error(`Pasarela de pago respondió ${result.status}`);
    wrapped.statusCode = 502;
    throw wrapped;
  }

  let data;
  try {
    data = JSON.parse(result.text);
  } catch {
    const wrapped = new Error('Pasarela de pago devolvió JSON inválido');
    wrapped.statusCode = 502;
    throw wrapped;
  }

  const url = typeof data?.url === 'string' ? data.url.trim() : '';
  if (!isHttpsUrl(url)) {
    const wrapped = new Error('Pasarela de pago devolvió una URL no HTTPS');
    wrapped.statusCode = 502;
    throw wrapped;
  }
  return url;
}
