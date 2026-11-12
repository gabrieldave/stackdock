#!/usr/bin/env node
/**
 * Bake static EN (/index.html) and ES (/es/index.html) from the bilingual shell.
 * - Applies dict[*] into every [data-i18n] node in the static source
 * - Root-relative /public/... asset paths (safe under /es/)
 * - Locale-specific <head> SEO / OpenGraph / canonical / hreflang
 * - No FOUC: pages ship already translated; toggle navigates / ↔ /es/
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WEB = path.resolve(__dirname, '..');
const SRC = path.join(WEB, 'shell.index.html');

const META = {
  en: {
    lang: 'en',
    title: 'StackDock v4.0 — Your Mac Dock on Every Display. 0.0% Idle CPU.',
    description:
      'StackDock 4.0 by BLACK EYE — Native macOS Dock on 2, 3, or 4+ displays with 0.0% idle CPU. Split Chrome profiles and teleport windows with Shift+Click. 7-day free trial, no credit card.',
    ogTitle: 'StackDock 4.0 — Your Mac Dock on Every Display. 0.0% Idle CPU.',
    ogDescription:
      'Summon frosted Docks with ⌥+D, split Chrome profiles into labeled icons, and teleport windows across monitors. Native Swift. Apple notarized.',
    ogUrl: 'https://stackdock.iareal.net/',
    ogLocale: 'en_US',
    canonical: 'https://stackdock.iareal.net/',
    twitterTitle: 'StackDock v4.0 — Your Mac Dock on Every Display. 0.0% Idle CPU.',
    twitterDescription:
      'Native multi-monitor Dock for macOS. 7-day free trial, no credit card. Personal $9.99 · Pro $19.',
  },
  es: {
    lang: 'es',
    title: 'StackDock v4.0 — Tu Dock de Mac en Cada Monitor. 0.0% CPU en Reposo.',
    description:
      'StackDock 4.0 por BLACK EYE — Proyecta tu Dock nativo de macOS en 2, 3 o 4+ monitores con 0.0% CPU en reposo, separa perfiles de Chrome y teletransporta ventanas con Shift+Clic. Prueba 7 días sin tarjeta.',
    ogTitle: 'StackDock 4.0 — Tu Dock de Mac en Cada Pantalla. 0.0% CPU.',
    ogDescription:
      'Invoca Docks de cristal con ⌥+D, separa perfiles de Chrome en iconos propios y teletransporta ventanas entre monitores. 100% Swift Nativo.',
    ogUrl: 'https://stackdock.iareal.net/es/',
    ogLocale: 'es_MX',
    canonical: 'https://stackdock.iareal.net/es/',
    twitterTitle: 'StackDock v4.0 — Tu Dock de Mac en Cada Monitor. 0.0% CPU en Reposo.',
    twitterDescription:
      'Dock multi-monitor nativo para macOS. Prueba 7 días sin tarjeta. Personal $9.99 · Pro $19.',
  },
};

/** Copy overrides required by the SEO handoff (bake into both dict + static HTML). */
function patchDict(dict) {
  // EN
  Object.assign(dict.en, {
    nav_studio: '3D Studio',
    nav_features: 'Architecture',
    nav_benchmark: 'Performance',
    nav_captures: 'M4 Captures',
    nav_compare: 'Compare',
    nav_pricing: 'Pricing',
    nav_cta: 'Buy from $9.99',
    hero_badge: '100% Native Swift • Apple Silicon M1–M4 & Intel • Apple Signed & Notarized',
    hero_h1: 'Your Mac Dock on every screen.<br class="hidden sm:inline" /> Instant. 0.0% idle CPU.',
    hero_sub:
      'On stacked or multi-monitor setups, macOS traps your Dock on a single screen. StackDock projects a native frosted-glass Dock across your <strong class="text-white font-semibold">2, 3, or 4+ displays</strong>: summon instantly with <span class="mac-kbd">⌥ + D</span>, split Chrome profiles into their own icons, and teleport windows proportionally with <span class="mac-kbd">Shift + Click</span>.',
    cta_trial: 'Start 7-Day Free Trial',
    cta_buy: 'Buy License — from $9.99',
    cta_subnote:
      'No credit card for trial • Personal $9.99 (1 Mac) · Pro $19 (3 Macs) • Offline Ed25519 license • macOS 13+',
    status_ready: 'Press ⌥ + D on your keyboard or test the controls below',
    drag_hint: 'Drag with mouse to rotate the 3D desk',
    am_badge_win: 'FROM $9.99 ONE-TIME',
    am_lbl_cpu: 'Idle CPU usage',
    am_lbl_ram: 'Real footprint on Apple M4',
    am_lbl_perm: 'Screen Recording Permission',
    am_val_perm_good: 'Never required',
    am_comp_name: '24/7 Video-Capture Docks',
    gal_eyebrow: 'REAL M4 CAPTURES • MAC MINI M4',
    faq_title: 'Frequently Asked Questions',
    pr_btn_trial: 'Start 7-Day Free Trial',
    pr_pro_f5: 'Priority support · Findaro bundle bump available at checkout',
    cmp_footnote: 'Public market check · November 2026 · competitor pricing/features may change',
  });

  // ES
  Object.assign(dict.es, {
    nav_studio: 'Estudio 3D',
    nav_features: 'Arquitectura',
    nav_benchmark: 'Rendimiento',
    nav_captures: 'Capturas M4',
    nav_compare: 'Comparativa',
    nav_pricing: 'Licencia',
    nav_cta: 'Comprar desde $9.99',
    hero_badge: '100% Swift Nativo • Apple Silicon M1–M4 e Intel • Firmado y Notarizado por Apple',
    hero_h1: 'Tu Dock de Mac en cada pantalla.<br class="hidden sm:inline" /> Instantáneo. 0.0% CPU en reposo.',
    hero_sub:
      'En monitores apilados o múltiples, macOS atrapa tu Dock en una sola pantalla. StackDock proyecta un Dock nativo de cristal en tus <strong class="text-white font-semibold">2, 3 o 4+ monitores</strong>: invócalo al instante con <span class="mac-kbd">⌥ + D</span>, separa perfiles de Chrome en iconos propios y mueve ventanas de pantalla con <span class="mac-kbd">Shift + Clic</span>.',
    cta_trial: 'Probar 7 Días Gratis — Sin Tarjeta',
    cta_buy: 'Comprar Licencia — desde $9.99',
    cta_subnote:
      'Sin tarjeta en la prueba • Personal $9.99 (1 Mac) · Pro $19 (3 Macs) • Licencia offline Ed25519 • macOS 13+',
    status_ready: 'Pulsa ⌥ + D en tu teclado o prueba los controles debajo',
    drag_hint: 'Arrastra con el mouse para girar el escritorio en 3D',
    am_badge_win: 'DESDE $9.99 PAGO ÚNICO',
    am_lbl_cpu: 'Uso de CPU en reposo',
    am_lbl_ram: 'Footprint real en Apple M4',
    am_lbl_perm: 'Permiso de Grabación de Pantalla',
    am_val_perm_good: 'Jamás requerido',
    am_comp_name: 'Docks con captura de video 24/7',
    gal_eyebrow: 'CAPTURAS REALES EN PRODUCCIÓN • MAC MINI M4',
    faq_title: 'Preguntas Frecuentes',
    pr_btn_trial: 'Probar 7 Días Gratis — Sin Tarjeta',
    pr_pro_f5: 'Soporte prioritario · Bundle Findaro disponible en checkout',
    pr_section_title: 'Precio simple. Tuyo para siempre.',
    pr_section_sub: 'Prueba completa 7 días — sin tarjeta. Luego elige Personal o Pro.',
    pr_eyebrow: 'LICENCIAS VITALICIAS',
    pr_popular: 'MÁS POPULAR',
    cmp_footnote: 'Revisión pública de mercado · noviembre 2026 · precios/funciones de terceros pueden cambiar',
  });

  return dict;
}

function extractDict(html) {
  const start = html.indexOf('const dict = {');
  if (start < 0) throw new Error('dict not found');
  // Find matching closing `};` at indent of dict declaration
  let i = start + 'const dict = '.length;
  let depth = 0;
  let end = -1;
  for (; i < html.length; i++) {
    const ch = html[i];
    if (ch === '{') depth++;
    else if (ch === '}') {
      depth--;
      if (depth === 0) {
        end = i + 1;
        break;
      }
    }
  }
  if (end < 0) throw new Error('dict end not found');
  const literal = html.slice(start + 'const dict = '.length, end);
  // eslint-disable-next-line no-new-func
  const dict = new Function(`return (${literal});`)();
  return { dict: patchDict(dict), start, end };
}

function replaceHead(html, locale) {
  const m = META[locale];
  html = html.replace(/<html\s+lang="[^"]*"/, `<html lang="${m.lang}"`);

  html = html.replace(
    /<meta name="description" content="[^"]*"\s*\/>/,
    `<meta name="description" content="${escAttr(m.description)}" />`
  );
  html = html.replace(/<meta property="og:url" content="[^"]*"\s*\/>/, `<meta property="og:url" content="${m.ogUrl}" />`);
  html = html.replace(
    /<meta property="og:locale" content="[^"]*"\s*\/>/,
    `<meta property="og:locale" content="${m.ogLocale}" />`
  );
  html = html.replace(
    /<meta property="og:title" content="[^"]*"\s*\/>/,
    `<meta property="og:title" content="${escAttr(m.ogTitle)}" />`
  );
  html = html.replace(
    /<meta property="og:description" content="[^"]*"\s*\/>/,
    `<meta property="og:description" content="${escAttr(m.ogDescription)}" />`
  );
  html = html.replace(
    /<link rel="canonical"[^>]*>/,
    `<link rel="canonical" href="${m.canonical}" id="canonical-link" />`
  );
  html = html.replace(/<title>[^<]*<\/title>/, `<title>${m.title}</title>`);
  html = html.replace(
    /<meta name="twitter:title" content="[^"]*"\s*\/>/,
    `<meta name="twitter:title" content="${escAttr(m.twitterTitle)}" />`
  );
  html = html.replace(
    /<meta name="twitter:description" content="[^"]*"\s*\/>/,
    `<meta name="twitter:description" content="${escAttr(m.twitterDescription)}" />`
  );

  // Ensure hreflang cluster present once
  if (!html.includes('hreflang="en"')) {
    html = html.replace(
      '<link rel="canonical"',
      `<link rel="alternate" hreflang="en" href="https://stackdock.iareal.net/" />
  <link rel="alternate" hreflang="es" href="https://stackdock.iareal.net/es/" />
  <link rel="alternate" hreflang="x-default" href="https://stackdock.iareal.net/" />
  <link rel="canonical"`
    );
  }

  // Early lang boot script: lock page lang, no navigator override
  const boot = `  <script>
    (function () {
      document.documentElement.lang = '${m.lang}';
      window.__SD_LANG__ = '${m.lang}';
    })();
  </script>`;
  html = html.replace(/<script>\s*\(function \(\) \{\s*var p =[\s\S]*?<\/script>/, boot);
  if (!html.includes("window.__SD_LANG__ = '" + m.lang + "'")) {
    html = html.replace('</head>', boot + '\n</head>');
  }

  return html;
}

function escAttr(s) {
  return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;');
}

function applyDataI18n(html, dictLang) {
  // Replace inner HTML of elements with data-i18n="key" — non-greedy across tags is hard;
  // match opening tag with data-i18n then content until matching close of same simple tags.
  return html.replace(
    /(<([a-zA-Z0-9]+)([^>]*\sdata-i18n="([^"]+)"[^>]*)>)([\s\S]*?)(<\/\2>)/g,
    (full, open, tag, attrs, key, _inner, close) => {
      if (!(key in dictLang)) return full;
      return `${open}${dictLang[key]}${close}`;
    }
  );
}

function rootRelativeAssets(html) {
  return html
    .replace(/(href|src)="\.\/public\//g, '$1="/public/')
    .replace(/(href|src)="public\//g, '$1="/public/')
    .replace(/url\(\.\/public\//g, 'url(/public/');
}

function patchStaticChrome(html, locale) {
  // Language pill visual defaults for the static page
  if (locale === 'en') {
    html = html.replace(
      /id="lang-es-pill" class="[^"]*"/,
      'id="lang-es-pill" class="px-1.5 py-0.5 rounded-full text-[#D4D4D8]"'
    );
    html = html.replace(
      /id="lang-en-pill" class="[^"]*"/,
      'id="lang-en-pill" class="px-1.5 py-0.5 rounded-full bg-[#F5F5F7] text-black"'
    );
    html = html.replace(
      'aria-label="Cambiar idioma ES / EN"',
      'aria-label="Switch language EN / ES"'
    );
    html = html.replace(
      'aria-label="Abrir menú de navegación"',
      'aria-label="Open navigation menu"'
    );
    html = html.replace(
      />✕ Cerrar</,
      '>✕ Close<'
    );
    html = html.replace(
      'alt="Vista ampliada StackDock"',
      'alt="StackDock expanded view"'
    );
    html = html.replace(
      />Real Mac mini M4 Capture</,
      '>Real Mac mini M4 Capture<'
    );
    // Lightbox defaults
    html = html.replace(
      /id="lb-title" class="[^"]*">[^<]*</,
      'id="lb-title" class="text-sm sm:text-base font-bold text-[#F5F5F7]">Real Mac mini M4 Capture<'
    );
    html = html.replace(
      'StackDock v4.0 • Built by',
      'StackDock v4.0 • Built by'
    );
    html = html.replace(
      'StackDock v4.0 • Creado por',
      'StackDock v4.0 • Built by'
    );
  } else {
    html = html.replace(
      /id="lang-es-pill" class="[^"]*"/,
      'id="lang-es-pill" class="px-1.5 py-0.5 rounded-full bg-[#F5F5F7] text-black"'
    );
    html = html.replace(
      /id="lang-en-pill" class="[^"]*"/,
      'id="lang-en-pill" class="px-1.5 py-0.5 rounded-full text-[#D4D4D8]"'
    );
    html = html.replace(
      'aria-label="Switch language EN / ES"',
      'aria-label="Cambiar idioma ES / EN"'
    );
    html = html.replace(
      'aria-label="Open navigation menu"',
      'aria-label="Abrir menú de navegación"'
    );
    html = html.replace(
      'aria-label="Cambiar idioma ES / EN"',
      'aria-label="Cambiar idioma ES / EN"'
    );
    html = html.replace(/>✕ Close</, '>✕ Cerrar<');
    html = html.replace(
      'alt="StackDock expanded view"',
      'alt="Vista ampliada StackDock"'
    );
    html = html.replace(
      /id="lb-title" class="[^"]*">[^<]*</,
      'id="lb-title" class="text-sm sm:text-base font-bold text-[#F5F5F7]">Captura Real Mac mini M4<'
    );
    html = html.replace(
      'StackDock v4.0 • Built by',
      'StackDock v4.0 • Creado por'
    );
  }

  // Compare footnote (static, after table card)
  if (!html.includes('id="cmp-footnote"')) {
    html = html.replace(
      `      </div>
    </div>
  </section>

  <!-- ================= 6. LIFETIME PRICING`,
      `        <p id="cmp-footnote" class="mt-4 text-center text-[11px] text-[#71717A]" data-i18n="cmp_footnote">${
        locale === 'en'
          ? 'Public market check · November 2026 · competitor pricing/features may change'
          : 'Revisión pública de mercado · noviembre 2026 · precios/funciones de terceros pueden cambiar'
      }</p>
      </div>
    </div>
  </section>

  <!-- ================= 6. LIFETIME PRICING`
    );
  } else {
    const foot =
      locale === 'en'
        ? 'Public market check · November 2026 · competitor pricing/features may change'
        : 'Revisión pública de mercado · noviembre 2026 · precios/funciones de terceros pueden cambiar';
    html = html.replace(
      /(<p id="cmp-footnote"[^>]*>)([\s\S]*?)(<\/p>)/,
      `$1${foot}$3`
    );
  }

  // Findaro bump: mark with data-bump so JS can hide when flag off
  html = html.replace(
    /(<span data-i18n="pr_pro_f5">)([\s\S]*?)(<\/span>)/,
    `$1${locale === 'en' ? dictSafe(locale, 'pr_pro_f5') : dictSafe(locale, 'pr_pro_f5')}$3`
  );
  html = html.replace(
    'data-i18n="pr_pro_f5"',
    'data-i18n="pr_pro_f5" data-findaro-bump="1"'
  );

  return html;
}

let GLOBAL_DICT = null;
function dictSafe(locale, key) {
  return (GLOBAL_DICT?.[locale]?.[key]) || '';
}

function rewriteRuntimeJs(html, locale, dict) {
  // Serialize patched dict back into the file
  const dictJson = serializeJsObject(dict);
  html = html.replace(/const dict = \{[\s\S]*?\n    \};/, `const dict = ${dictJson};`);

  // Config: ENABLE_FINDARO_BUMP + pageLang
  html = html.replace(
    /const STACKDOCK_CONFIG = \{/,
    `const STACKDOCK_CONFIG = {\n      enableFindaroBump: '__ENABLE_FINDARO_BUMP__' === '1' || '__ENABLE_FINDARO_BUMP__' === 'true',`
  );

  // Force currentLang from documentElement — never navigator
  html = html.replace(
    /let currentLang = \(typeof window\.__SD_LANG__ === 'string'\) \? window\.__SD_LANG__ : 'en';/,
    `let currentLang = (document.documentElement.lang === 'es') ? 'es' : 'en';`
  );

  // Replace applyLanguage / syncLangUrl / toggle with navigation-based switcher
  const navToggle = `
    function pageLang() {
      return document.documentElement.lang === 'es' ? 'es' : 'en';
    }
    currentLang = pageLang();

    function applyLanguage(lang) {
      // Static pages are already baked. Only update dynamic runtime strings.
      currentLang = lang === 'es' ? 'es' : 'en';
      updateProfileBadgeTextures();
      refreshDynamicBadges();
    }

    function navigateLocale(targetLang) {
      const hash = location.hash || '';
      const dest = targetLang === 'es' ? '/es/' : '/';
      if (pageLang() === targetLang) {
        applyLanguage(targetLang);
        return;
      }
      location.assign(dest + hash);
    }

    document.getElementById('lang-toggle').addEventListener('click', () => {
      navigateLocale(pageLang() === 'es' ? 'en' : 'es');
    });

    // Honor Findaro bump flag in Pricing Pro card
    (function applyFindaroBumpVisibility() {
      const show = !!STACKDOCK_CONFIG.enableFindaroBump;
      document.querySelectorAll('[data-findaro-bump]').forEach((el) => {
        const row = el.closest('li') || el;
        row.classList.toggle('hidden', !show);
      });
    })();
`;

  // Remove old applyLanguage + syncLangUrl + langPath + toggle listener block
  html = html.replace(
    /function langPath\(lang\) \{[\s\S]*?document\.getElementById\('lang-toggle'\)\.addEventListener\('click', \(\) => \{\s*applyLanguage\(currentLang === 'es' \? 'en' : 'es'\);\s*\}\);/,
    navToggle.trim()
  );

  // Also handle older applyLanguage-only form if present
  if (html.includes("document.getElementById('lang-toggle').addEventListener('click', () => {\n      applyLanguage(currentLang === 'es' ? 'en' : 'es');\n    });")) {
    html = html.replace(
      /function applyLanguage\(lang[\s\S]*?document\.getElementById\('lang-toggle'\)\.addEventListener\('click', \(\) => \{\s*applyLanguage\(currentLang === 'es' \? 'en' : 'es'\);\s*\}\);/,
      navToggle.trim()
    );
  }

  // Webhook payload: lang + locale
  html = html.replace(
    /locale: currentLang,/,
    `locale: currentLang,\n        lang: currentLang,`
  );

  // Remove FOUC applyLanguage on boot
  html = html.replace(
    /\n\s*\/\/ Apply EN \(default \/\) or ES \(\/es\) before first paint interactions\n\s*applyLanguage\(currentLang, \{ updateUrl: true \}\);\n/,
    `\n    // Static HTML is locale-baked; only sync dynamic HUD strings.\n    applyLanguage(pageLang());\n`
  );

  // Modal default static chrome for locale
  if (locale === 'en') {
    html = html.replace(
      /id="modal-title" class="text-xl font-bold text-\[#F5F5F7\] mb-2">[^<]*</,
      'id="modal-title" class="text-xl font-bold text-[#F5F5F7] mb-2">Download StackDock v4.0<'
    );
  } else {
    html = html.replace(
      /id="modal-title" class="text-xl font-bold text-\[#F5F5F7\] mb-2">[^<]*</,
      'id="modal-title" class="text-xl font-bold text-[#F5F5F7] mb-2">Descargar StackDock v4.0<'
    );
  }

  return html;
}

function serializeJsObject(obj, indent = 4) {
  const pad = (n) => ' '.repeat(n);
  function ser(v, level) {
    if (v === null) return 'null';
    if (typeof v === 'boolean' || typeof v === 'number') return String(v);
    if (typeof v === 'string') return JSON.stringify(v);
    if (Array.isArray(v)) {
      if (!v.length) return '[]';
      return '[\n' + v.map((x) => pad(level + 2) + ser(x, level + 2)).join(',\n') + '\n' + pad(level) + ']';
    }
    if (typeof v === 'object') {
      const keys = Object.keys(v);
      if (!keys.length) return '{}';
      return (
        '{\n' +
        keys
          .map((k) => {
            const key = /^[A-Za-z_][A-Za-z0-9_]*$/.test(k) ? k : JSON.stringify(k);
            return pad(level + 2) + key + ': ' + ser(v[k], level + 2);
          })
          .join(',\n') +
        '\n' +
        pad(level) +
        '}'
      );
    }
    return JSON.stringify(String(v));
  }
  return ser(obj, indent / 2);
}

function bake(locale, dict) {
  let html = fs.readFileSync(SRC, 'utf8');
  GLOBAL_DICT = dict;
  html = replaceHead(html, locale);
  html = applyDataI18n(html, dict[locale]);
  html = rootRelativeAssets(html);
  html = patchStaticChrome(html, locale);
  html = rewriteRuntimeJs(html, locale, dict);

  // Production constants must remain verbatim
  const must = [
    'StackDock-4.0.3.dmg',
    '5cc46c726ac89771d1eb8b06e7aa2d51b9be41888a2fb42633168f92a3c06e4d',
    'YH6W55MP95',
    'stackdock@iareal.net',
    'https://wa.me/525645674407',
  ];
  for (const m of must) {
    if (!html.includes(m)) throw new Error(`Missing production value in ${locale}: ${m}`);
  }

  return html;
}

function main() {
  const raw = fs.readFileSync(SRC, 'utf8');
  const { dict } = extractDict(raw);

  const en = bake('en', dict);
  const es = bake('es', dict);

  const esDir = path.join(WEB, 'es');
  fs.mkdirSync(esDir, { recursive: true });
  fs.writeFileSync(path.join(WEB, 'index.html'), en);
  fs.writeFileSync(path.join(esDir, 'index.html'), es);
  console.log('baked EN bytes', en.length);
  console.log('baked ES bytes', es.length);
}

main();
