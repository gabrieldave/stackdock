import test from 'node:test';
import assert from 'node:assert/strict';
import { computeQuote, buildPaymentPayload, PRICES_CENTS } from '../src/pricing.js';

test('precios exactos', () => {
  assert.equal(PRICES_CENTS.personal, 999);
  assert.equal(PRICES_CENTS.pro, 1900);
  assert.equal(PRICES_CENTS.findaro, 2900);
});

test('personal sin bump = 999', () => {
  const quote = computeQuote({ plan: 'personal', addFindaro: false, locale: 'es' });
  assert.equal(quote.amountCents, 999);
  assert.equal(quote.currency, 'usd');
  assert.equal(quote.locale, 'es');
  assert.equal(quote.addFindaro, false);
});

test('pro sin bump = 1900', () => {
  const quote = computeQuote({ plan: 'pro', addFindaro: false });
  assert.equal(quote.amountCents, 1900);
});

test('pro + findaro = 4800', () => {
  const quote = computeQuote({ plan: 'pro', addFindaro: true, locale: 'en' });
  assert.equal(quote.amountCents, 4800);
  assert.equal(quote.addFindaro, true);
});

test('personal + findaro => 400', () => {
  assert.throws(
    () => computeQuote({ plan: 'personal', addFindaro: true }),
    (error) => error.statusCode === 400,
  );
});

test('plan inválido o email inválido => 400', () => {
  assert.throws(() => computeQuote({ plan: 'enterprise' }), (error) => error.statusCode === 400);
  assert.throws(() => computeQuote({}), (error) => error.statusCode === 400);
  assert.throws(
    () => computeQuote({ plan: 'pro', customerEmail: 'nope' }),
    (error) => error.statusCode === 400,
  );
});

test('payload al gateway: moneda usd y sin currency_options.usd', () => {
  const quote = computeQuote({ plan: 'pro', addFindaro: true, locale: 'es', customerEmail: 'Buyer@Example.com ' });
  const payload = buildPaymentPayload(quote, { locale: 'es' });

  assert.equal(payload.product, 'stackdock');
  assert.equal(payload.plan, 'pro');
  assert.equal(payload.addFindaro, true);
  assert.equal(payload.amount_cents, 4800);
  assert.equal(payload.currency, 'usd');
  assert.equal(payload.locale, 'es');
  assert.equal(payload.customer_email, 'buyer@example.com');
  assert.deepEqual(payload.metadata, { product: 'stackdock', plan: 'pro', locale: 'es' });
  assert.equal(JSON.stringify(payload).includes('currency_options'), false);
});
