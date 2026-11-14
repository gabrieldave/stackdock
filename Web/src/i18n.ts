import { copy, funnel, type Locale } from './config/funnel';

let loc: Locale = (document.documentElement.dataset.locale as Locale) || 'en';
export const currentLocale = () => loc;
export const isPreview = () => document.documentElement.dataset.mode === 'preview' || location.protocol === 'file:';

function get(path: string): string | undefined {
  const v = path.split('.').reduce<any>((o, k) => (o == null ? o : o[k]), copy[loc]);
  return typeof v === 'string' ? v : undefined;
}

export function applyLocale(next: Locale) {
  loc = next;
  const html = document.documentElement;
  html.lang = next;
  html.dataset.locale = next;
  document.querySelectorAll<HTMLElement>('[data-i18n]').forEach((el) => {
    const v = get(el.dataset.i18n!);
    if (v != null && el.innerHTML !== v) el.innerHTML = v;
  });
  document.querySelectorAll<HTMLElement>('[data-i18n-attr]').forEach((el) => {
    el.dataset.i18nAttr!.split(';').forEach((pair) => {
      const [attr, path] = pair.split(':');
      const v = get(path);
      if (v != null) el.setAttribute(attr, v);
    });
  });
  document.title = copy[next].meta.title;
  document.querySelectorAll<HTMLAnchorElement>('[data-lang]').forEach((a) => {
    if (a.dataset.lang === next) a.setAttribute('aria-current', 'true');
    else a.removeAttribute('aria-current');
  });
  const home = document.querySelector<HTMLAnchorElement>('[data-home]');
  if (home) home.href = next === 'en' ? '/' : '/es/';
  const wa = document.querySelector<HTMLAnchorElement>('[data-wa]');
  if (wa) wa.href = `https://wa.me/${funnel.whatsapp.e164}?text=${encodeURIComponent(copy[next].whatsapp.prefill)}`;
  document.dispatchEvent(new CustomEvent('sd:locale', { detail: next }));
}

function setCookie(l: Locale) {
  const secure = location.protocol === 'https:' ? '; Secure' : '';
  document.cookie = `${funnel.langCookie}=${l}; Max-Age=31536000; Path=/; SameSite=Lax${secure}`;
}

export function initI18n() {
  // Vista previa de un solo archivo: #es activa español
  if (isPreview() && location.hash === '#es' && loc !== 'es') applyLocale('es');

  document.querySelectorAll<HTMLAnchorElement>('[data-lang]').forEach((a) => {
    a.addEventListener('click', (e) => {
      e.preventDefault();
      const next = a.dataset.lang as Locale;
      setCookie(next);
      if (next === loc) return;
      if (isPreview()) history.replaceState(null, '', next === 'es' ? '#es' : location.pathname + location.search);
      else history.pushState({ loc: next }, '', (next === 'es' ? '/es/' : '/') + location.hash);
      applyLocale(next);
    });
  });

  window.addEventListener('popstate', () => {
    let next: Locale;
    if (isPreview()) {
      if (location.hash === '#es') next = 'es';
      else if (location.hash === '') next = 'en';
      else return; // anclas internas (#how, #pricing…) no cambian idioma
    } else next = location.pathname.startsWith('/es') ? 'es' : 'en';
    if (next !== loc) applyLocale(next);
  });
}
