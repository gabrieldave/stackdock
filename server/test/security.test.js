import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { encryptSecret, decryptSecret, hashLicenseKey, safeDecrypt } from '../src/crypto-store.js';
import { createRateLimiter } from '../src/rate-limit.js';
import { seatDecision } from '../src/api.js';
import { revokedStatusForEvent, verifyStripeSignature } from '../src/webhooks.js';

const SECRET = 'test-session-secret-32-chars-min-000';

test('AES-256-GCM: cifra y descifra licencias (roundtrip)', () => {
  const key = 'SDOCK-abc123-_xyz';
  const enc = encryptSecret(key, SECRET);
  assert.ok(enc.startsWith('enc:v1:'), 'formato enc:v1');
  assert.notEqual(enc, key);
  assert.equal(decryptSecret(enc, SECRET), key);
});

test('AES-256-GCM: IV único por fila', () => {
  const a = encryptSecret('same-plaintext', SECRET);
  const b = encryptSecret('same-plaintext', SECRET);
  assert.notEqual(a, b);
  assert.notEqual(a.split('.')[0], b.split('.')[0]);
});

test('AES-256-GCM: detecta manipulación (authTag)', () => {
  const enc = encryptSecret('SDOCK-secret', SECRET);
  const parts = enc.split('.');
  const tampered = `${parts[0]}.${parts[1]}.${Buffer.from('evil').toString('base64url')}`;
  assert.throws(() => decryptSecret(tampered, SECRET));
});

test('AES-256-GCM: secreto distinto no descifra', () => {
  const enc = encryptSecret('SDOCK-secret', SECRET);
  assert.throws(() => decryptSecret(enc, 'otro-secret-de-prueba-1234567890'));
});

test('hashLicenseKey es SHA-256 estable y no reversible', () => {
  const hash = hashLicenseKey(' SDOCK-xyz ');
  assert.match(hash, /^[a-f0-9]{64}$/);
  assert.equal(hash, hashLicenseKey('SDOCK-xyz'));
  assert.equal(safeDecrypt('texto-legado', SECRET), 'texto-legado');
});

test('rate limiting: 10 intentos por 15 min y bloqueo del 11º', () => {
  const limiter = createRateLimiter({ max: 10, windowMs: 15 * 60 * 1000 });
  const t0 = 1_800_000_000_000;
  for (let i = 0; i < 10; i += 1) {
    assert.equal(limiter.check('1.2.3.4', t0 + i).limited, false, `intento ${i + 1}`);
  }
  const blocked = limiter.check('1.2.3.4', t0 + 10);
  assert.equal(blocked.limited, true);
  assert.ok(blocked.retryAfter > 0);
  // Otra IP no se ve afectada
  assert.equal(limiter.check('5.6.7.8', t0 + 11).limited, false);
  // Pasada la ventana vuelve a permitir
  assert.equal(limiter.check('1.2.3.4', t0 + 15 * 60 * 1000 + 1).limited, false);
});

test('asientos Personal: 1 Mac, misma Mac idempotente y 2ª bloqueada', () => {
  assert.equal(seatDecision({ plan: 'personal', existingDevice: false, devicesUsed: 0 }).allowed, true);
  const second = seatDecision({ plan: 'personal', existingDevice: false, devicesUsed: 1 });
  assert.equal(second.allowed, false);
  assert.equal(second.reason, 'seat_limit_exceeded');
  assert.equal(second.seats, 1);
  assert.equal(seatDecision({ plan: 'personal', existingDevice: true, devicesUsed: 1 }).allowed, true);
});

test('asientos Pro: 3 Macs permitidas y 4ª bloqueada', () => {
  for (let used = 0; used < 3; used += 1) {
    assert.equal(seatDecision({ plan: 'pro', existingDevice: false, devicesUsed: used }).allowed, true);
  }
  const fourth = seatDecision({ plan: 'pro', existingDevice: false, devicesUsed: 3 });
  assert.equal(fourth.allowed, false);
  assert.equal(fourth.seats, 3);
  assert.equal(seatDecision({ plan: 'pro', existingDevice: true, devicesUsed: 3 }).allowed, true);
});

function signedHeader(rawBody, secret, timestamp = Math.floor(Date.now() / 1000)) {
  const signature = crypto.createHmac('sha256', secret).update(`${timestamp}.${rawBody}`, 'utf8').digest('hex');
  return `t=${timestamp},v1=${signature}`;
}

test('webhook firmado: reembolso verifica Stripe-Signature y mapea a refunded', () => {
  const secret = 'whsec_test_secret';
  const body = Buffer.from(JSON.stringify({
    id: 'evt_refund_1',
    type: 'charge.refunded',
    data: { object: { id: 'ch_1', payment_intent: 'pi_1', amount_refunded: 1900 } },
  }), 'utf8');
  assert.equal(verifyStripeSignature(body, signedHeader(body.toString('utf8'), secret), secret), true);
  assert.equal(revokedStatusForEvent('charge.refunded'), 'refunded');
  assert.equal(revokedStatusForEvent('charge.dispute.created'), 'revoked');
  assert.equal(revokedStatusForEvent('checkout.session.completed'), null);
});

test('webhook firmado: firma inválida o expirada se rechaza', () => {
  const secret = 'whsec_test_secret';
  const body = Buffer.from('{"type":"charge.refunded"}', 'utf8');
  const wrong = signedHeader(body.toString('utf8'), 'whsec_otro');
  assert.throws(() => verifyStripeSignature(body, wrong, secret));
  const expired = signedHeader(body.toString('utf8'), secret, Math.floor(Date.now() / 1000) - 400);
  assert.throws(() => verifyStripeSignature(body, expired, secret));
});
