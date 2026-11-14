import test from 'node:test';
import assert from 'node:assert/strict';
import { UPDATE_CACHE_CONTROL, headersForUpdates, cacheControlFor } from '../src/static.js';

test('el feed de actualizaciones se sirve con Cache-Control: no-store', () => {
  assert.equal(UPDATE_CACHE_CONTROL, 'no-store');
  const headers = headersForUpdates();
  assert.equal(headers['Cache-Control'], 'no-store');
  assert.ok(!/public/i.test(headers['Cache-Control']));
  assert.ok(!/max-age/i.test(headers['Cache-Control']));
});

test('los assets con hash conservan caché inmutable', () => {
  assert.match(cacheControlFor('/assets/main-abc123.js'), /immutable/);
});
