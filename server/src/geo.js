/**
 * Detección de idioma sin dependencias externas.
 * 1) cookie stackdock-lang manda
 * 2) bots => EN sin redirección (SEO: una sola URL canónica por idioma)
 * 3) país (cf-ipcountry / x-vercel-ip-country)
 * 4) Accept-Language empezando por es como respaldo
 */

export const SPANISH_COUNTRIES = new Set([
  'MX', 'AR', 'BO', 'CL', 'CO', 'CR', 'CU', 'DO', 'EC', 'SV', 'GQ',
  'GT', 'HN', 'NI', 'PA', 'PY', 'PE', 'PR', 'ES', 'UY', 'VE',
]);

export const BOT_PATTERN =
  /Googlebot|bingbot|DuckDuckBot|Slurp|Baiduspider|YandexBot|Applebot|Twitterbot|facebookexternalhit|LinkedInBot/i;

export function parseCookies(req) {
  const header = String(req?.headers?.cookie || '');
  const cookies = {};
  for (const part of header.split(';')) {
    const index = part.indexOf('=');
    if (index === -1) continue;
    const name = part.slice(0, index).trim();
    if (!name || name in cookies) continue;
    cookies[name] = decodeURIComponent(part.slice(index + 1).trim());
  }
  return cookies;
}

export function cookieLocale(req) {
  const value = String(parseCookies(req)['stackdock-lang'] || '').trim().toLowerCase();
  return value === 'es' || value === 'en' ? value : '';
}

export function headerCountry(req) {
  const raw = String(
    req?.headers?.['cf-ipcountry'] || req?.headers?.['x-vercel-ip-country'] || '',
  ).trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(raw)) return '';
  if (raw === 'XX' || raw === 'T1') return '';
  return raw;
}

export function isBot(req) {
  return BOT_PATTERN.test(String(req?.headers?.['user-agent'] || ''));
}

export function isSpanishCountry(country) {
  return SPANISH_COUNTRIES.has(String(country || '').toUpperCase());
}

function acceptsSpanish(req) {
  const header = String(req?.headers?.['accept-language'] || '').trim().toLowerCase();
  if (!header) return false;
  const first = header.split(',')[0]?.trim() || '';
  return first === 'es' || first.startsWith('es-') || first.startsWith('es_');
}

/**
 * @returns {{locale: 'en'|'es', redirect: boolean, country: string}}
 * redirect=true solo cuando la raíz debe enviar a /es/.
 */
export function resolveLocale(req) {
  const country = headerCountry(req);

  const fromCookie = cookieLocale(req);
  if (fromCookie) {
    return { locale: fromCookie, redirect: fromCookie === 'es', country };
  }

  if (isBot(req)) {
    return { locale: 'en', redirect: false, country };
  }

  if (country) {
    const spanish = isSpanishCountry(country);
    return { locale: spanish ? 'es' : 'en', redirect: spanish, country };
  }

  if (acceptsSpanish(req)) {
    return { locale: 'es', redirect: true, country: '' };
  }

  return { locale: 'en', redirect: false, country: '' };
}
