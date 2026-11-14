/**
 * Checkout Session directo con la API oficial de Stripe.
 *
 * Se usa como respaldo del Payment Gateway Universal (n8n) cuando la pasarela
 * no soporta todavía el appId "stackdock". Moneda base SIEMPRE usd y nunca se
 * envía currency_options (Adaptive Pricing lo gestiona Stripe en el panel).
 */
import { config } from './config.js';
import { HttpError } from './http.js';

const STRIPE_API = 'https://api.stripe.com/v1/checkout/sessions';

function planLineItem(quote) {
  if (quote.plan === 'personal') {
    return { name: 'StackDock Personal (1 Mac)', amount: 999 };
  }
  return { name: 'StackDock Pro (up to 3 Macs)', amount: 1900 };
}

/**
 * @param {{ plan: 'personal'|'pro', addFindaro: boolean, amountCents: number, locale: 'en'|'es', customerEmail?: string }} quote
 * @returns {Promise<string>} URL de Stripe Checkout
 */
export async function createStripeCheckout(quote) {
  if (!config.stripeSecretKey) {
    throw new HttpError(503, 'Pasarela de pago sin STRIPE_SECRET_KEY');
  }

  const base = planLineItem(quote);
  const items = [{ name: base.name, amount: base.amount }];
  if (quote.plan === 'pro' && quote.addFindaro) {
    items.push({ name: 'Findaro Solo (1 Mac)', amount: 2900 });
  }

  const form = new URLSearchParams();
  form.set('mode', 'payment');
  form.set('currency', 'usd');
  form.set('locale', quote.locale === 'es' ? 'es' : 'auto');
  form.set('success_url', `${config.publicUrl}/pago/success?session_id={CHECKOUT_SESSION_ID}`);
  form.set('cancel_url', `${config.publicUrl}/#pricing`);
  form.set('metadata[app]', 'stackdock');
  form.set('metadata[plan]', quote.plan);
  form.set('metadata[addFindaro]', quote.addFindaro ? 'true' : 'false');
  form.set('metadata[locale]', quote.locale);
  form.set('payment_intent_data[metadata][app]', 'stackdock');
  form.set('payment_intent_data[metadata][plan]', quote.plan);
  form.set('payment_intent_data[metadata][addFindaro]', quote.addFindaro ? 'true' : 'false');
  if (quote.customerEmail) form.set('customer_email', quote.customerEmail);

  items.forEach((item, index) => {
    form.set(`line_items[${index}][quantity]`, '1');
    form.set(`line_items[${index}][price_data][currency]`, 'usd');
    form.set(`line_items[${index}][price_data][unit_amount]`, String(item.amount));
    form.set(`line_items[${index}][price_data][product_data][name]`, item.name);
  });

  let response;
  try {
    response = await fetch(STRIPE_API, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${config.stripeSecretKey}`,
        'Content-Type': 'application/x-www-form-urlencoded',
        Accept: 'application/json',
        'User-Agent': `StackDock-Server/${config.version}`,
      },
      body: form.toString(),
      signal: AbortSignal.timeout(15_000),
    });
  } catch (error) {
    throw new HttpError(502, `Stripe no disponible: ${error.message}`);
  }

  const text = await response.text();
  let data = {};
  try {
    data = JSON.parse(text);
  } catch {
    throw new HttpError(502, 'Stripe devolvió una respuesta inválida');
  }

  if (!response.ok) {
    const hint = data?.error?.message || `Stripe respondió ${response.status}`;
    throw new HttpError(502, `Stripe: ${String(hint).slice(0, 160)}`);
  }

  const url = typeof data?.url === 'string' ? data.url : '';
  if (!url.startsWith('https://checkout.stripe.com/')) {
    throw new HttpError(502, 'Stripe no devolvió una URL de checkout válida');
  }
  return url;
}
