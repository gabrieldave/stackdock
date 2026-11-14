/**
 * Router HTTP: estáticos + API + auth + páginas. Sin frameworks.
 */
import { query } from './db.js';
import {
  applySecurityHeaders,
  escapeHtml,
  isHttps,
  methodNotAllowed,
  redirect,
  sendHtml,
  sendJson,
  serializeCookie,
} from './http.js';
import { cookieLocale, resolveLocale } from './geo.js';
import { serveDmg, servePublic, serveStorage, headersForUpdates, UPDATE_CACHE_CONTROL } from './static.js';
import { handleCheckout, handleHealth, handleTrial } from './api.js';
import { handlePaymentWebhook } from './webhooks.js';
import { getAdminEmail, handleGoogleCallback, handleGoogleStart, handleLogout } from './auth.js';
import { getDashboardData, handleIssueLicense, handleResendLicense } from './admin.js';
import { renderAdminPage, renderNotFoundPage, renderSuccessPage } from './pages.js';

const LANG_COOKIE = 'stackdock-lang';
const ONE_YEAR_SECONDS = 365 * 24 * 60 * 60;

function isRead(req) {
  return req.method === 'GET' || req.method === 'HEAD';
}

function wantsHtml(req) {
  const accept = String(req.headers.accept || '');
  return accept.includes('text/html');
}

async function serveRoot(req, res, url) {
  const detected = resolveLocale(req);
  const requestedLang = String(url.searchParams.get('lang') || '').toLowerCase();
  const previousCookie = cookieLocale(req);
  const headers = {
    Vary: 'CF-IPCountry, Cookie, Accept-Language',
    'Cache-Control': 'no-store',
  };

  if (requestedLang === 'es' || requestedLang === 'en') {
    headers['Set-Cookie'] = serializeCookie(LANG_COOKIE, requestedLang, {
      maxAge: ONE_YEAR_SECONDS,
      sameSite: 'Lax',
      secure: isHttps(req),
    });
    redirect(res, requestedLang === 'es' ? '/es/' : '/', headers);
    return;
  }

  if (previousCookie) {
    headers['Set-Cookie'] = serializeCookie(LANG_COOKIE, previousCookie, {
      maxAge: ONE_YEAR_SECONDS,
      sameSite: 'Lax',
      secure: isHttps(req),
    });
  }

  if (detected.redirect && detected.locale === 'es') {
    redirect(res, '/es/', headers);
    return;
  }

  const served = await servePublic(req, res, '/index.html', {
    cacheControl: 'no-store',
    extraHeaders: {
      Vary: headers.Vary,
      ...(headers['Set-Cookie'] ? { 'Set-Cookie': headers['Set-Cookie'] } : {}),
    },
  });
  if (!served) {
    sendJson(res, 500, { error: 'Web no desplegada' });
  }
}

async function serveSpanishHome(req, res) {
  const ok = await servePublic(req, res, '/es/index.html');
  if (!ok) {
    const fallback = await servePublic(req, res, '/index.html');
    if (!fallback) sendJson(res, 500, { error: 'Web no desplegada' });
  }
}

async function getOrderBySession(sessionId) {
  if (!sessionId) return null;
  try {
    const result = await query(
      `SELECT id, email, plan, add_findaro, amount_cents, currency, status, license_key, findaro_key, locale
       FROM orders WHERE stripe_session_id = $1 LIMIT 1`,
      [sessionId],
    );
    return result.rows[0] || null;
  } catch (error) {
    if (error.statusCode === 503) return null;
    throw error;
  }
}

async function serveSuccess(req, res, url) {
  const sessionId = String(url.searchParams.get('session_id') || '').trim();
  const order = await getOrderBySession(sessionId);
  const geo = resolveLocale(req);
  const locale = order?.locale === 'es' || (!order && geo.locale === 'es') ? 'es' : 'en';
  sendHtml(res, 200, renderSuccessPage({ order, locale, sessionId }));
}

async function serveAdmin(req, res) {
  const email = await getAdminEmail(req);
  if (!email) {
    redirect(res, '/api/auth/google');
    return;
  }
  const data = await getDashboardData();
  const locale = cookieLocale(req) || (resolveLocale(req).locale === 'es' ? 'es' : 'en');
  sendHtml(res, 200, renderAdminPage({ email, ...data, locale }));
}

function handleError(req, res, error) {
  const status = Number(error?.statusCode) || 500;
  if (status >= 500) {
    console.error('[http]', req.method, req.url, '-', error?.message || 'error');
    if (status === 500 && error?.stack) console.error(error.stack.split('\n').slice(0, 6).join('\n'));
  }
  if (res.headersSent) {
    res.destroy();
    return;
  }
  const isApi = String(req.url || '').startsWith('/api/');
  if (isApi || !wantsHtml(req)) {
    const message = status >= 500 ? 'Error interno' : error.message;
    sendJson(res, status, { error: message }, error.headers || {});
    return;
  }
  const page = status === 404
    ? renderNotFoundPage('en')
    : `<!DOCTYPE html><html lang="en"><meta charset="utf-8"><title>Error</title><body style="font-family:-apple-system,sans-serif;background:#E6E5E0;color:#111;padding:48px"><h1>Error</h1><p>${escapeHtml(status >= 500 ? 'Internal error' : error.message)}</p><a href="/">Home</a></body></html>`;
  sendHtml(res, status, page, error.headers || {});
}

export function createHandler() {
  return async function handler(req, res) {
    applySecurityHeaders(res);
    const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
    const pathname = url.pathname;

    try {
      if (pathname === '/api/health') {
        if (!isRead(req)) return methodNotAllowed(res, 'GET, HEAD');
        return handleHealth(req, res);
      }

      if (pathname === '/') {
        if (!isRead(req)) return methodNotAllowed(res, 'GET, HEAD');
        return await serveRoot(req, res, url);
      }

      if (pathname === '/es' || pathname === '/es/') {
        if (!isRead(req)) return methodNotAllowed(res, 'GET, HEAD');
        return await serveSpanishHome(req, res);
      }

      if (pathname === '/api/trial') {
        if (req.method !== 'POST') return methodNotAllowed(res, 'POST');
        return await handleTrial(req, res);
      }

      if (pathname === '/api/checkout') {
        if (req.method !== 'POST') return methodNotAllowed(res, 'POST');
        return await handleCheckout(req, res);
      }

      if (pathname === '/api/webhooks/stripe' || pathname === '/api/webhooks/n8n') {
        if (req.method !== 'POST') return methodNotAllowed(res, 'POST');
        return await handlePaymentWebhook(req, res);
      }

      if (pathname === '/api/auth/google') {
        if (req.method !== 'GET') return methodNotAllowed(res, 'GET');
        return handleGoogleStart(req, res);
      }

      if (pathname === '/api/auth/callback/google') {
        if (req.method !== 'GET') return methodNotAllowed(res, 'GET');
        return await handleGoogleCallback(req, res, url);
      }

      if (pathname === '/api/admin/logout') {
        if (req.method !== 'POST') return methodNotAllowed(res, 'POST');
        return await handleLogout(req, res);
      }

      if (pathname === '/api/admin/resend-license') {
        if (req.method !== 'POST') return methodNotAllowed(res, 'POST');
        return await handleResendLicense(req, res);
      }

      if (pathname === '/api/admin/issue-license') {
        if (req.method !== 'POST') return methodNotAllowed(res, 'POST');
        return await handleIssueLicense(req, res);
      }

      if (pathname === '/admin' || pathname === '/admin/') {
        if (!isRead(req)) return methodNotAllowed(res, 'GET, HEAD');
        return await serveAdmin(req, res);
      }

      if (pathname === '/pago/success' || pathname === '/pago/success/') {
        if (!isRead(req)) return methodNotAllowed(res, 'GET, HEAD');
        return await serveSuccess(req, res, url);
      }

      const dmgMatch = /^\/download\/([A-Za-z0-9._-]+\.dmg)$/.exec(pathname);
      if (dmgMatch) {
        if (!isRead(req)) return methodNotAllowed(res, 'GET, HEAD');
        return await serveDmg(req, res, dmgMatch[1]);
      }

      if (pathname === '/updates/latest.json' || pathname === '/updates/latest.json.sig') {
        if (!isRead(req)) return methodNotAllowed(res, 'GET, HEAD');
        // Triple sello: el feed jamás se cachea (no-store, sin public ni max-age).
        for (const [key, value] of Object.entries(headersForUpdates())) res.setHeader(key, value);
        const fromStorage = await serveStorage(req, res, pathname, { cacheControl: UPDATE_CACHE_CONTROL });
        if (fromStorage) return;
        const fromPublic = await servePublic(req, res, pathname, { cacheControl: UPDATE_CACHE_CONTROL });
        if (fromPublic) return;
        sendJson(res, 404, { error: 'Archivo no encontrado' });
        return;
      }

      if (pathname.startsWith('/api/')) {
        sendJson(res, 404, { error: 'Ruta no encontrada' });
        return;
      }

      if (isRead(req)) {
        const served = await servePublic(req, res, pathname);
        if (served) return;
        sendHtml(res, 404, renderNotFoundPage(resolveLocale(req).locale));
        return;
      }

      sendJson(res, 404, { error: 'Ruta no encontrada' });
    } catch (error) {
      handleError(req, res, error);
    }
  };
}
