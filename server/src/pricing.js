/**
 * Precios y cotización del checkout. Sin red ni BD: testeable en aislamiento.
 * Base USD (nunca currency_options.usd hacia el gateway).
 */

export const PRICES_CENTS = {
  personal: 999,
  pro: 1900,
  findaro: 2900,
};

export const CURRENCY = 'usd';

function badRequest(message) {
  const error = new Error(message);
  error.statusCode = 400;
  return error;
}

/** Normaliza el body de /api/checkout y calcula el importe exacto. */
export function computeQuote(body) {
  const plan = String(body?.plan || '').trim().toLowerCase();
  if (plan !== 'personal' && plan !== 'pro') throw badRequest('plan inválido');

  const addFindaro = body?.addFindaro === true || body?.addFindaro === 'true' || body?.addFindaro === 1;
  if (plan === 'personal' && addFindaro) {
    throw badRequest('Findaro Solo solo está disponible con el plan Pro');
  }

  const locale = String(body?.locale || 'en').trim().toLowerCase() === 'es' ? 'es' : 'en';
  const rawEmail = String(body?.customerEmail || '').trim().toLowerCase();
  if (rawEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(rawEmail)) {
    throw badRequest('customerEmail inválido');
  }

  const amountCents = PRICES_CENTS[plan] + (addFindaro ? PRICES_CENTS.findaro : 0);

  return {
    plan,
    addFindaro,
    locale,
    customerEmail: rawEmail,
    amountCents,
    currency: CURRENCY,
  };
}

/** Payload exacto enviado al Payment Gateway Universal (n8n). */
export function buildPaymentPayload(quote, metadata = {}) {
  return {
    product: 'stackdock',
    plan: quote.plan,
    addFindaro: quote.addFindaro,
    amount_cents: quote.amountCents,
    currency: CURRENCY,
    locale: quote.locale,
    customer_email: quote.customerEmail || null,
    metadata: { product: 'stackdock', plan: quote.plan, ...metadata },
  };
}
