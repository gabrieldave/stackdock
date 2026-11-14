import './styles/main.css';
import './styles/art.css';
import { funnel, isPending } from './config/funnel';
import { initI18n, currentLocale } from './i18n';
import { initHero } from './hero';
import { initCommerce } from './commerce';

const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;

// ── Chasis físico fijo: aparición de secciones ────────────────
function countUp(el: HTMLElement) {
  if (el.dataset.counted) return;
  el.dataset.counted = '1';
  const isMoney = el.hasAttribute('data-money');
  const target = Number(isMoney ? el.dataset.money : el.dataset.count);
  const decimals = isMoney ? (Number.isInteger(target) ? 0 : 2) : (el.dataset.count!.split('.')[1] || '').length;
  const fmt = (v: number) => (isMoney ? '$' : '') + v.toFixed(decimals);
  if (reduced || target === 0) { el.textContent = fmt(target); return; }
  const t0 = performance.now();
  const dur = 900;
  const step = (t: number) => {
    const k = Math.min(1, (t - t0) / dur);
    const e = 1 - Math.pow(1 - k, 3);
    el.textContent = fmt(target * e);
    if (k < 1) requestAnimationFrame(step);
    else el.textContent = fmt(target);
  };
  requestAnimationFrame(step);
}

function initReveal() {
  const html = document.documentElement;
  const items = document.querySelectorAll<HTMLElement>('[data-reveal]');
  const done = (el: Element) => {
    el.classList.add('is-revealed');
    el.querySelectorAll<HTMLElement>('[data-count],[data-money]').forEach(countUp);
  };
  if (!html.classList.contains('js-reveal') || !('IntersectionObserver' in window)) {
    items.forEach(done);
    return;
  }
  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((en) => {
        if (!en.isIntersecting) return;
        done(en.target);
        io.unobserve(en.target);
      });
    },
    { threshold: 0.1, rootMargin: '0px 0px -8% 0px' },
  );
  items.forEach((el) => io.observe(el));
}

// ── Narrativa sticky (desktop) ────────────────────────────────
function initSticky() {
  const steps = document.querySelectorAll<HTMLElement>('.step');
  const figs = document.querySelectorAll<HTMLElement>('[data-fig]');
  const idx = document.querySelector<HTMLElement>('[data-fig-idx]');
  const set = (i: number) => {
    figs.forEach((f) => f.classList.toggle('is-on', Number(f.dataset.fig) === i));
    steps.forEach((s) => s.classList.toggle('is-current', Number(s.dataset.step) === i));
    if (idx) idx.textContent = `${'ABC'[i]} / C`;
  };
  const io = new IntersectionObserver(
    (entries) => entries.forEach((en) => { if (en.isIntersecting) set(Number((en.target as HTMLElement).dataset.step)); }),
    { rootMargin: '-45% 0px -45% 0px' },
  );
  steps.forEach((s) => io.observe(s));
}

// ── Visor del Panel 4.0.6 (captura real o wireframe) ─────────
function initPanel() {
  const viewer = document.querySelector<HTMLElement>('[data-viewer]');
  if (!viewer) return;
  const img = viewer.querySelector<HTMLImageElement>('[data-panel-img]')!;
  const load = () => {
    const src = currentLocale() === 'es' ? img.dataset.srcEs! : img.dataset.srcEn!;
    const probe = new Image();
    probe.onload = () => { img.src = src; img.hidden = false; viewer.classList.add('has-img'); };
    probe.onerror = () => { img.hidden = true; viewer.classList.remove('has-img'); };
    probe.src = src;
  };
  load();
  document.addEventListener('sd:locale', load);

  const link = (n: string, on: boolean) => {
    viewer.querySelector(`[data-marker="${n}"]`)?.classList.toggle('is-hot', on);
    document.querySelector(`[data-callout="${n}"]`)?.classList.toggle('is-hot', on);
  };
  document.querySelectorAll<HTMLElement>('[data-callout]').forEach((c) => {
    const n = c.dataset.callout!;
    ['pointerenter', 'focus'].forEach((ev) => c.addEventListener(ev, () => link(n, true)));
    ['pointerleave', 'blur'].forEach((ev) => c.addEventListener(ev, () => link(n, false)));
  });
  viewer.querySelectorAll<HTMLElement>('[data-marker]').forEach((mk) => {
    const n = mk.dataset.marker!;
    ['pointerenter', 'focus'].forEach((ev) => mk.addEventListener(ev, () => link(n, true)));
    ['pointerleave', 'blur'].forEach((ev) => mk.addEventListener(ev, () => link(n, false)));
    mk.addEventListener('click', () => document.querySelector<HTMLElement>(`[data-callout="${n}"]`)?.focus());
  });
}

// ── Lite-YouTube facade ───────────────────────────────────────
function initVideo() {
  const box = document.querySelector<HTMLElement>('[data-lite]');
  const id = box?.dataset.videoId;
  if (!box || !id || isPending(id)) return;
  const btn = box.querySelector<HTMLButtonElement>('[data-lite-play]')!;
  let warmed = false;
  const warm = () => {
    if (warmed) return;
    warmed = true;
    ['https://www.youtube-nocookie.com', 'https://i.ytimg.com'].forEach((h) => {
      const l = document.createElement('link');
      l.rel = 'preconnect';
      l.href = h;
      document.head.appendChild(l);
    });
  };
  btn.addEventListener('pointerenter', warm, { once: true });
  btn.addEventListener('focus', warm, { once: true });
  btn.addEventListener('click', () => {
    const f = document.createElement('iframe');
    f.src = `https://www.youtube-nocookie.com/embed/${encodeURIComponent(id)}?autoplay=1&rel=0&modestbranding=1&hl=${currentLocale()}`;
    f.title = 'StackDock tutorial';
    f.allow = 'accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture';
    f.allowFullscreen = true;
    f.className = 'lite-frame';
    box.replaceChildren(f);
  });
}

// ── Nav ───────────────────────────────────────────────────────
function initNav() {
  const nav = document.querySelector<HTMLElement>('[data-nav]');
  if (!nav) return;
  const onScroll = () => nav.classList.toggle('is-scrolled', scrollY > 8);
  addEventListener('scroll', onScroll, { passive: true });
  onScroll();
}

// ── Burbuja WhatsApp: en móvil no tapa el Hero vivo ───────────
function initWa() {
  const hero = document.querySelector('.hero');
  if (!hero) return;
  const mq = matchMedia('(max-width: 680px)');
  let heroOn = true;
  const apply = () => document.documentElement.classList.toggle('wa-hide', mq.matches && heroOn);
  new IntersectionObserver((en) => { heroOn = en[0]?.isIntersecting ?? false; apply(); }, { rootMargin: '0px 0px -35% 0px' }).observe(hero);
  mq.addEventListener('change', apply);
}

initI18n();
initWa();
initReveal();
initNav();
const rig = document.querySelector<HTMLElement>('[data-rig]');
if (rig) initHero(rig);
initSticky();
initPanel();
initVideo();
initCommerce();

// Exponer la versión para soporte (sin datos personales)
(window as unknown as { STACKDOCK: unknown }).STACKDOCK = { version: funnel.version, build: funnel.build };
