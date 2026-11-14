import test from 'node:test';
import assert from 'node:assert/strict';
import { resolveLocale, isSpanishCountry, parseCookies } from '../src/geo.js';

function req(headers = {}) {
  return { headers };
}

test('la cookie stackdock-lang manda sobre país', () => {
  const result = resolveLocale(req({
    cookie: 'a=1; stackdock-lang=en; b=2',
    'cf-ipcountry': 'MX',
    'user-agent': 'Mozilla/5.0',
  }));
  assert.deepEqual(result, { locale: 'en', redirect: false, country: 'MX' });

  const es = resolveLocale(req({ cookie: 'stackdock-lang=es', 'cf-ipcountry': 'US' }));
  assert.equal(es.locale, 'es');
  assert.equal(es.redirect, true);
  assert.equal(es.country, 'US');
});

test('los bots reciben EN sin redirección aunque el país sea hispanohablante', () => {
  for (const ua of [
    'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
    'Mozilla/5.0 (compatible; bingbot/2.0)',
    'facebookexternalhit/1.1',
    'LinkedInBot/1.0',
    'Twitterbot/1.0',
  ]) {
    const result = resolveLocale(req({ 'cf-ipcountry': 'MX', 'user-agent': ua }));
    assert.equal(result.locale, 'en');
    assert.equal(result.redirect, false);
  }
});

test('MX sin cookie => español con redirección', () => {
  const result = resolveLocale(req({ 'cf-ipcountry': 'MX', 'user-agent': 'Mozilla/5.0' }));
  assert.deepEqual(result, { locale: 'es', redirect: true, country: 'MX' });
});

test('US sin cookie => inglés sin redirección', () => {
  const result = resolveLocale(req({ 'cf-ipcountry': 'US', 'user-agent': 'Mozilla/5.0' }));
  assert.deepEqual(result, { locale: 'en', redirect: false, country: 'US' });
});

test('país desconocido y Accept-Language español de respaldo => ES', () => {
  const result = resolveLocale(req({ 'accept-language': 'es-ES,es;q=0.9,en;q=0.8' }));
  assert.equal(result.locale, 'es');
  assert.equal(result.redirect, true);
  assert.equal(result.country, '');
});

test('Accept-Language inglés de respaldo => EN', () => {
  const result = resolveLocale(req({ 'accept-language': 'en-US,en;q=0.9' }));
  assert.equal(result.locale, 'en');
  assert.equal(result.redirect, false);
});

test('cf-ipcountry vacío o XX cae al respaldo', () => {
  assert.equal(resolveLocale(req({ 'cf-ipcountry': 'XX', 'accept-language': 'es-MX' })).locale, 'es');
  assert.equal(resolveLocale(req({ 'cf-ipcountry': '', 'accept-language': 'en-GB' })).locale, 'en');
});

test('x-vercel-ip-country como alternativa y país hispanohablante', () => {
  const result = resolveLocale(req({ 'x-vercel-ip-country': 'AR' }));
  assert.equal(result.locale, 'es');
  assert.equal(result.redirect, true);
  assert.equal(result.country, 'AR');
});

test('lista de países ES completa', () => {
  const expected = ['ES', 'MX', 'AR', 'BO', 'CL', 'CO', 'CR', 'CU', 'DO', 'EC', 'SV', 'GQ', 'GT', 'HN', 'NI', 'PA', 'PY', 'PE', 'PR', 'UY', 'VE'];
  for (const country of expected) assert.equal(isSpanishCountry(country), true, country);
  for (const country of ['US', 'CA', 'BR', 'DE', 'FR', 'JP']) assert.equal(isSpanishCountry(country), false, country);
});

test('parseCookies tolera valores codificados y cookies repetidas', () => {
  const cookies = parseCookies({ headers: { cookie: 'stackdock-lang=es; x=a%20b; x=dup' } });
  assert.equal(cookies['stackdock-lang'], 'es');
  assert.equal(cookies.x, 'a b');
});
