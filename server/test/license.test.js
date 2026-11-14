import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { signLicense, verifyLicense, parsePrivateKey, publicKeyFromPrivate } from '../src/license.js';

const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
const seed = privateKey.export({ format: 'der', type: 'pkcs8' }).subarray(-32);
const SEED_B64 = seed.toString('base64');
const PEM = privateKey.export({ format: 'pem', type: 'pkcs8' }).toString();

function signatureOf(licenseKey) {
  return Buffer.from(licenseKey.slice('SDOCK-'.length), 'base64url');
}

test('personal: payload exacto y firma verificable', () => {
  const key = signLicense('Buyer@Example.com ', 'personal', SEED_B64);
  assert.match(key, /^SDOCK-[A-Za-z0-9_-]+$/);
  assert.equal(key.includes('='), false);
  assert.equal(verifyLicense(key, 'buyer@example.com', 'personal', publicKey), true);
  assert.equal(verifyLicense(key, 'buyer@example.com', 'pro', publicKey), false);
});

test('pro: payload `email|stackdock-pro|3macs`', () => {
  const key = signLicense('buyer@example.com', 'pro', SEED_B64);
  const ok = crypto.verify(
    null,
    Buffer.from('buyer@example.com|stackdock-pro|3macs', 'utf8'),
    publicKey,
    signatureOf(key),
  );
  assert.equal(ok, true);
});

test('findaro: payload `email|findaro-solo|1mac`', () => {
  const key = signLicense('buyer@example.com', 'findaro', SEED_B64);
  const ok = crypto.verify(
    null,
    Buffer.from('buyer@example.com|findaro-solo|1mac', 'utf8'),
    publicKey,
    signatureOf(key),
  );
  assert.equal(ok, true);
});

test('acepta la misma clave como PEM PKCS8', () => {
  const fromPem = signLicense('buyer@example.com', 'pro', PEM);
  const fromSeed = signLicense('buyer@example.com', 'pro', SEED_B64);
  assert.equal(verifyLicense(fromPem, 'buyer@example.com', 'pro', publicKey), true);
  // Ed25519 es determinista: misma clave + mismo payload => misma firma.
  assert.equal(fromPem, fromSeed);
  assert.equal(publicKeyFromPrivate(PEM).export({ format: 'pem', type: 'spki' }).toString(),
    publicKey.export({ format: 'pem', type: 'spki' }).toString());
});

test('clave ausente => error 503 explícito (nunca clave falsa)', () => {
  assert.throws(
    () => signLicense('buyer@example.com', 'pro', ''),
    (error) => error.statusCode === 503,
  );
  assert.throws(
    () => parsePrivateKey('no-es-base64-de-32-bytes'),
    (error) => error.statusCode === 503,
  );
});

test('email o plan inválidos => 400', () => {
  assert.throws(() => signLicense('no-email', 'pro', SEED_B64), (error) => error.statusCode === 400);
  assert.throws(() => signLicense('buyer@example.com', 'enterprise', SEED_B64), (error) => error.statusCode === 400);
});

test('una firma manipulada no verifica', () => {
  const key = signLicense('buyer@example.com', 'pro', SEED_B64);
  const tampered = `${key.slice(0, -2)}${key.endsWith('A') ? 'BB' : 'AA'}`;
  assert.equal(verifyLicense(tampered, 'buyer@example.com', 'pro', publicKey), false);
});
