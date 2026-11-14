import { funnel, copy, isPending, usd, savingsMath, type Locale, type Copy } from './config/funnel';
import { figDock, figProfiles, figTeleport, panelWireframe } from './figures';

export type Mode = 'site' | 'preview';
export interface RenderOpts {
  locale: Locale;
  mode: Mode;
  /** Resuelve rutas de /public (en preview devuelve data: URIs) */
  asset: (path: string) => string;
}

const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function get(c: Copy, path: string): string {
  const v = path.split('.').reduce<any>((o, k) => (o == null ? o : o[k]), c);
  if (typeof v !== 'string') throw new Error(`copy path no es string: ${path}`);
  return v;
}

export function render({ locale, mode, asset }: RenderOpts): string {
  const c = copy[locale];
  const t = (p: string) => get(c, p);
  /** atributo + contenido traducible */
  const A = (p: string) => `data-i18n="${p}"`;

  const base = funnel.siteUrl;
  const canonical = locale === 'en' ? `${base}/` : `${base}/es/`;
  const shaPending = isPending(funnel.sha256);
  const pr = funnel.prices;
  const s = savingsMath;
  const scriptSrc = mode === 'preview' ? '/src/preview-entry.ts' : '/src/main.ts';
  const ogImg = `${base}/og-${locale}.jpg`;

  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    name: 'StackDock',
    applicationCategory: 'UtilitiesApplication',
    operatingSystem: `macOS ${funnel.minMacOS}`,
    softwareVersion: funnel.version,
    publisher: { '@type': 'Organization', name: 'BLACK EYE' },
    url: canonical,
    inLanguage: locale,
    offers: [
      { '@type': 'Offer', name: 'StackDock Personal (1 Mac)', price: pr.personal.usd.toFixed(2), priceCurrency: 'USD' },
      { '@type': 'Offer', name: 'StackDock Pro (3 Macs)', price: pr.pro.usd.toFixed(2), priceCurrency: 'USD' },
    ],
  };

  const specRows = (rows: readonly (readonly string[])[], base: string) =>
    rows.map((r, i) => `<div class="spec-row"><dt ${A(`${base}.${i}.0`)}>${r[0]}</dt><dd ${A(`${base}.${i}.1`)}>${r[1]}</dd></div>`).join('');

  const steps = c.how.steps
    .map(
      (st, i) => `
      <article class="step" data-step="${i}" data-reveal style="--i:${i}">
        <p class="kicker mono" ${A(`how.steps.${i}.kicker`)}>${st.kicker}</p>
        <h3 ${A(`how.steps.${i}.title`)}>${st.title}</h3>
        <p class="pain"><span class="pain-tag mono" aria-hidden="true">!</span><span ${A(`how.steps.${i}.pain`)}>${st.pain}</span></p>
        <p class="body" ${A(`how.steps.${i}.body`)}>${st.body}</p>
        <dl class="spec">${specRows(st.specs, `how.steps.${i}.specs`)}</dl>
        <div class="step-fig-m" aria-hidden="true">${[figDock, figProfiles, figTeleport][i]}</div>
      </article>`,
    )
    .join('');

  const callouts = c.panel.callouts
    .map(
      (co, i) => `
      <li class="callout" data-callout="${i + 1}" tabindex="0" data-reveal style="--i:${i}">
        <span class="num mono">${'①②③④⑤⑥'[i]}</span>
        <div><h4 ${A(`panel.callouts.${i}.title`)}>${co.title}</h4><p ${A(`panel.callouts.${i}.body`)}>${co.body}</p></div>
      </li>`,
    )
    .join('');

  const markers = funnel.panel.callouts
    .map((m) => `<button type="button" class="marker mono" data-marker="${m.n}" style="left:${m.x}%;top:${m.y}%" aria-label="${m.n}">${'①②③④⑤⑥'[m.n - 1]}</button>`)
    .join('');

  const faq = c.faq.items
    .map(
      (it, i) => `
      <details class="qa" data-reveal style="--i:${i % 4}">
        <summary><span class="mono qn">Q${String(i + 1).padStart(2, '0')}</span><span ${A(`faq.items.${i}.q`)}>${it.q}</span><span class="plus" aria-hidden="true"></span></summary>
        <p ${A(`faq.items.${i}.a`)}>${it.a}</p>
      </details>`,
    )
    .join('');

  const feat = (k: 'personal' | 'pro') =>
    c.pricing[k].features.map((f, i) => `<li><span class="tick" aria-hidden="true"></span><span ${A(`pricing.${k}.features.${i}`)}>${f}</span></li>`).join('');

  const videoReady = !isPending(funnel.youtubeVideoId);

  return `<!DOCTYPE html>
<html lang="${locale}" data-locale="${locale}" data-mode="${mode}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title ${A('meta.title')}>${t('meta.title')}</title>
<meta name="description" content="${esc(t('meta.description'))}" data-i18n-attr="content:meta.description">
<meta name="theme-color" content="#E6E5E0">
<link rel="canonical" href="${canonical}">
<link rel="alternate" hreflang="en" href="${base}/">
<link rel="alternate" hreflang="es" href="${base}/es/">
<link rel="alternate" hreflang="x-default" href="${base}/">
<meta property="og:type" content="website">
<meta property="og:site_name" content="StackDock">
<meta property="og:title" content="${esc(t('meta.title'))}">
<meta property="og:description" content="${esc(t('meta.description'))}">
<meta property="og:url" content="${canonical}">
<meta property="og:image" content="${ogImg}">
<meta property="og:image:width" content="1200"><meta property="og:image:height" content="630">
<meta property="og:image:alt" content="${esc(t('meta.ogAlt'))}">
<meta property="og:locale" content="${locale === 'en' ? 'en_US' : 'es_MX'}">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="${asset('/favicon.svg')}" type="image/svg+xml">
<link rel="icon" href="${asset('/favicon-32x32.png')}" sizes="32x32">
<link rel="apple-touch-icon" href="${asset('/apple-touch-icon.png')}">
${mode === 'site' ? '<link rel="manifest" href="/site.webmanifest">' : ''}
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@62..125,300..800&family=IBM+Plex+Mono:wght@400;500;600&display=swap">
<script>(function(){var d=document.documentElement;d.classList.add('js');if(!matchMedia('(prefers-reduced-motion: reduce)').matches){d.classList.add('js-reveal')}})();</script>
<script type="application/ld+json">${JSON.stringify(jsonLd)}</script>
</head>
<body>
<a class="skip" href="#main" ${A('nav.skip')}>${t('nav.skip')}</a>

<header class="nav" data-nav>
  <div class="wrap nav-in">
    <a class="brand" href="${locale === 'en' ? '/' : '/es/'}" data-home>
      <img src="${asset('/media/appicon-128.webp')}" width="28" height="28" alt="">
      <span>StackDock</span><span class="ver mono">${funnel.version}</span>
    </a>
    <nav class="links" aria-label="Main">
      <a href="#how" ${A('nav.how')}>${t('nav.how')}</a>
      <a href="#panel" ${A('nav.panel')}>${t('nav.panel')}</a>
      <a href="#proof" ${A('nav.proof')}>${t('nav.proof')}</a>
      <a href="#pricing" ${A('nav.pricing')}>${t('nav.pricing')}</a>
      <a href="#faq" ${A('nav.faq')}>${t('nav.faq')}</a>
    </nav>
    <div class="nav-r">
      <div class="lang mono" role="group" aria-label="Language">
        <a href="/" data-lang="en" ${locale === 'en' ? 'aria-current="true"' : ''} hreflang="en">EN</a><span aria-hidden="true">|</span><a href="/es/" data-lang="es" ${locale === 'es' ? 'aria-current="true"' : ''} hreflang="es">ES</a>
      </div>
      <button type="button" class="btn btn-key btn-sm" data-open-download ${A('nav.download')}>${t('nav.download')}</button>
    </div>
  </div>
</header>

<main id="main">
<!-- ═══ HERO ═══ -->
<section class="hero grid-paper" id="top">
  <div class="wrap hero-in">
    <div class="hero-copy">
      <div class="hero-a">
      <p class="eyebrow mono" data-reveal style="--i:0"><span class="led" aria-hidden="true"></span><span ${A('hero.eyebrow')}>${t('hero.eyebrow')}</span></p>
      <h1 data-reveal style="--i:1"><span class="l1" ${A('hero.h1a')}>${t('hero.h1a')}</span> <span class="l2" ${A('hero.h1b')}>${t('hero.h1b')}</span></h1>
      </div>
      <div class="hero-b">
      <p class="lede" data-reveal style="--i:2" ${A('hero.sub')}>${t('hero.sub')}</p>
      <div class="cta-row" data-reveal style="--i:3">
        <button type="button" class="btn btn-key" data-open-download ${A('hero.ctaTrial')}>${t('hero.ctaTrial')}</button>
        <a class="btn btn-ghost" href="#pricing" ${A('hero.ctaBuy')}>${t('hero.ctaBuy')}</a>
      </div>
      <p class="micro mono" data-reveal style="--i:4" ${A('hero.micro')}>${t('hero.micro')}</p>
      </div>
    </div>

    <figure class="rig" data-rig data-reveal style="--i:2">
      <figcaption class="rig-head mono"><span ${A('hero.figLabel')}>${t('hero.figLabel')}</span><span class="rig-note" ${A('hero.figNote')}>${t('hero.figNote')}</span></figcaption>
      <div class="stage" data-stage>
        <svg class="stage-lines" viewBox="0 0 640 600" preserveAspectRatio="none" aria-hidden="true">
          <path d="M64 22h512M64 16v12M576 16v12" class="dim"/>
          <text x="320" y="16" class="lbl c">2560 pt</text>
          <path d="M44 40v288M38 40h12M38 328h12" class="dim"/>
          <text x="30" y="188" class="lbl v">1440 pt</text>
          <path d="M128 584h384M128 578v12M512 578v12" class="dim"/>
          <text x="320" y="598" class="lbl c">1920 pt</text>
          <path d="M108 352v216M102 352h12M102 568h12" class="dim"/>
          <text x="94" y="464" class="lbl v">1080 pt</text>
          <path d="M0 574h640" class="desk"/>
          <path d="M8 8h10M8 8v10M632 8h-10M632 8v10" class="reg"/>
        </svg>
        <div class="screen" data-screen="0" style="left:10%;top:6.6667%;width:80%;height:48%">
          <div class="menubar"><span class="apple" aria-hidden="true"></span></div>
          <div class="apple-dock" data-apple-dock></div>
        </div>
        <div class="screen" data-screen="1" style="left:20%;top:58.6667%;width:60%;height:36%">
          <div class="menubar"></div>
        </div>
        <span class="screen-tag mono" data-screen-tag="0" style="left:10.4%;top:4.9%"></span>
        <span class="screen-tag mono" data-screen-tag="1" style="left:20.4%;top:55.6%"></span>
        <div class="winlayer" data-winlayer></div>
        <div class="docklayer" data-docklayer></div>
        <svg class="trace-layer" viewBox="0 0 640 600" preserveAspectRatio="none" aria-hidden="true"><g data-trace></g></svg>
      </div>

      <div class="console" data-console>
        <div class="ctl ctl-rotary">
          <span class="ctl-label mono" ${A('hero.ctlPlacement')}>${t('hero.ctlPlacement')}</span>
          <div class="rotary-wrap">
            <div class="rotary" data-rotary role="slider" tabindex="0" aria-valuemin="0" aria-valuemax="3" aria-valuenow="1" aria-label="${esc(t('hero.ctlPlacement'))}">
              <span class="knob"><span class="pointer"></span></span>
            </div>
            <span class="det mono" data-det="0">BTM</span><span class="det mono" data-det="1">ELEV</span><span class="det mono" data-det="2">TOP</span><span class="det mono" data-det="3">AUTO</span>
          </div>
        </div>
        <div class="ctl ctl-switches">
          <div class="sw-row"><span class="ctl-label mono" ${A('hero.ctlIsolate')}>${t('hero.ctlIsolate')}</span>
            <button type="button" class="switch" data-toggle="isolate" aria-pressed="false"><span class="sw-a mono" ${A('hero.isolateOff')}>${t('hero.isolateOff')}</span><span class="sw-track"><span class="sw-thumb"></span></span><span class="sw-b mono" ${A('hero.isolateOn')}>${t('hero.isolateOn')}</span></button></div>
          <div class="sw-row"><span class="ctl-label mono" ${A('hero.ctlMode')}>${t('hero.ctlMode')}</span>
            <button type="button" class="switch" data-toggle="dual" aria-pressed="false"><span class="sw-a mono" ${A('hero.modeSolo')}>${t('hero.modeSolo')}</span><span class="sw-track"><span class="sw-thumb"></span></span><span class="sw-b mono" ${A('hero.modeDual')}>${t('hero.modeDual')}</span></button></div>
          <div class="sw-row"><span class="ctl-label mono" ${A('hero.ctlSplit')}>${t('hero.ctlSplit')}</span>
            <button type="button" class="switch" data-toggle="split" aria-pressed="true"><span class="sw-a mono" ${A('hero.splitOff')}>${t('hero.splitOff')}</span><span class="sw-track"><span class="sw-thumb"></span></span><span class="sw-b mono" ${A('hero.splitOn')}>${t('hero.splitOn')}</span></button></div>
        </div>
        <div class="ctl ctl-key">
          <span class="ctl-label mono" ${A('hero.ctlKey')}>${t('hero.ctlKey')}</span>
          <button type="button" class="keycap" data-keycap aria-keyshortcuts="Control+W"><span class="kc-top"><span class="kc-mod">⌃</span><span class="kc-w">W</span></span></button>
          <span class="key-hint mono" data-key-hint>${t('hero.keyHintOther')}</span>
        </div>
        <div class="lcd mono" data-lcd aria-live="polite">
          <div class="lcd-l" data-lcd-1>${t('hero.readoutIdle')}</div>
          <div class="lcd-l dim" data-lcd-2>&nbsp;</div>
          <div class="lcd-l dim" data-lcd-3>&nbsp;</div>
          <div class="lcd-l st" data-lcd-4>&nbsp;</div>
        </div>
      </div>
      <p class="rig-foot mono"><span data-placement-note></span> <span class="sep">·</span> <span ${A('hero.shiftHint')}>${t('hero.shiftHint')}</span></p>
    </figure>
  </div>
</section>

<!-- ═══ HOW (sticky narrative) ═══ -->
<section class="how" id="how">
  <div class="wrap">
    <header class="sec-head" data-reveal>
      <p class="eyebrow mono" ${A('how.eyebrow')}>${t('how.eyebrow')}</p>
      <h2 ${A('how.h2')}>${t('how.h2')}</h2>
    </header>
    <div class="how-grid">
      <div class="how-sticky" aria-hidden="true">
        <div class="plate">
          <div class="plate-head mono"><span>FIG. 02</span><span data-fig-idx>A / C</span></div>
          <div class="plate-figs">
            <div class="pf is-on" data-fig="0">${figDock}</div>
            <div class="pf" data-fig="1">${figProfiles}</div>
            <div class="pf" data-fig="2">${figTeleport}</div>
          </div>
        </div>
      </div>
      <div class="how-steps">${steps}</div>
    </div>
  </div>
</section>

<!-- ═══ PANEL 4.0.6 ═══ -->
<section class="panel grid-paper" id="panel">
  <div class="wrap">
    <header class="sec-head" data-reveal>
      <p class="eyebrow mono" ${A('panel.eyebrow')}>${t('panel.eyebrow')}</p>
      <h2 ${A('panel.h2')}>${t('panel.h2')}</h2>
      <p class="sec-sub" ${A('panel.sub')}>${t('panel.sub')}</p>
    </header>
    <div class="panel-grid">
      <figure class="viewer" data-viewer data-reveal>
        <figcaption class="viewer-head mono"><span ${A('panel.figLabel')}>${t('panel.figLabel')}</span><span class="viewer-state" data-viewer-state ${A('panel.pending')}>${t('panel.pending')}</span></figcaption>
        <div class="viewer-body">
          ${panelWireframe(esc(t('panel.figLabel')))}
          <img class="viewer-img" data-panel-img data-src-en="${asset(funnel.panel.media.en)}" data-src-es="${asset(funnel.panel.media.es)}" src="${asset(funnel.panel.media[locale])}" alt="${esc(t('panel.figLabel'))}" loading="lazy" decoding="async" hidden>
          ${markers}
        </div>
      </figure>
      <ol class="callouts">${callouts}</ol>
    </div>
  </div>
</section>

<!-- ═══ VIDEO ═══ -->
<section class="video" id="video">
  <div class="wrap video-grid">
    <header class="sec-head" data-reveal>
      <p class="eyebrow mono" ${A('video.eyebrow')}>${t('video.eyebrow')}</p>
      <h2 ${A('video.h2')}>${t('video.h2')}</h2>
      <p class="sec-sub mono small" ${A('video.privacy')}>${t('video.privacy')}</p>
    </header>
    <div class="lite" data-lite data-video-id="${videoReady ? esc(funnel.youtubeVideoId) : ''}" data-reveal>
      ${
        videoReady
          ? `<button type="button" class="lite-btn" data-lite-play aria-label="${esc(t('video.play'))}" style="background-image:url('https://i.ytimg.com/vi/${esc(funnel.youtubeVideoId)}/hqdefault.jpg')"><span class="lite-play" aria-hidden="true"></span><span class="lite-label mono" ${A('video.play')}>${t('video.play')}</span></button>`
          : `<div class="lite-pending">
              <div class="lp-screen" aria-hidden="true">
                <div class="lp-scan"></div>
                <span class="lite-play is-off"></span>
                <span class="lp-tc mono">00:00 / --:--</span>
              </div>
              <div class="lp-copy">
                <p class="lp-title" ${A('video.pendingTitle')}>${t('video.pendingTitle')}</p>
                <p class="lp-body" ${A('video.pendingBody')}>${t('video.pendingBody')}</p>
                <ol class="lp-steps">${c.video.steps.map((sx, i) => `<li><span class="mono">${String(i + 1).padStart(2, '0')}</span><span ${A(`video.steps.${i}`)}>${sx}</span></li>`).join('')}</ol>
              </div>
            </div>`
      }
    </div>
  </div>
</section>

<!-- ═══ PROOF ═══ -->
<section class="proof grid-paper" id="proof">
  <div class="wrap">
    <header class="sec-head" data-reveal>
      <p class="eyebrow mono" ${A('proof.eyebrow')}>${t('proof.eyebrow')}</p>
      <h2 ${A('proof.h2')}>${t('proof.h2')}</h2>
    </header>
    <div class="stats">
      ${c.proof.stats
        .map(
          (st, i) => `<div class="stat" data-reveal style="--i:${i}"><p class="stat-v"><span class="num" data-count="${st.value}">${st.value}</span><span class="unit mono">${st.unit}</span></p><p class="stat-l mono" ${A(`proof.stats.${i}.label`)}>${st.label}</p></div>`,
        )
        .join('')}
    </div>
    <dl class="spec spec-wide" data-reveal>${specRows(c.proof.bullets, 'proof.bullets')}</dl>
    <p class="foot mono" data-reveal ${A('proof.footnote')}>${t('proof.footnote')}</p>
    <div class="captures">
      <p class="cap-label mono" data-reveal ${A('proof.capturesLabel')}>${t('proof.capturesLabel')}</p>
      <div class="cap-grid">
        ${funnel.captures
          .map(
            (cp, i) => `<figure class="cap" data-reveal style="--i:${i}"><img src="${asset(cp.src)}" width="${cp.w}" height="${cp.h}" alt="${esc(c.proof.captures[i])}" loading="lazy" decoding="async"><figcaption class="mono"><span class="cap-n">CAP. ${String(i + 1).padStart(2, '0')}</span> <span ${A(`proof.captures.${i}`)}>${c.proof.captures[i]}</span></figcaption></figure>`,
          )
          .join('')}
      </div>
    </div>
  </div>
</section>

<!-- ═══ SAVINGS ═══ -->
<section class="savings" id="savings">
  <div class="wrap">
    <header class="sec-head" data-reveal>
      <p class="eyebrow mono" ${A('savings.eyebrow')}>${t('savings.eyebrow')}</p>
      <h2 ${A('savings.h2')}>${t('savings.h2')}</h2>
    </header>
    <div class="table-wrap" data-reveal>
      <table class="cost">
        <thead><tr><th scope="col"><span class="sr" ${A('savings.rowUs')}>${t('savings.rowUs')}</span></th><th scope="col" class="mono" ${A('savings.col1')}>${t('savings.col1')}</th><th scope="col" class="mono" ${A('savings.col3')}>${t('savings.col3')}</th></tr></thead>
        <tbody>
          <tr class="us"><th scope="row"><span ${A('savings.rowUs')}>${t('savings.rowUs')}</span><small class="mono" ${A('savings.rowUsSub')}>${t('savings.rowUsSub')}</small></th><td class="mono" data-money="${pr.personal.usd}">${usd(pr.personal.usd)}</td><td class="mono" data-money="${pr.pro.usd}">${usd(pr.pro.usd)}</td></tr>
          <tr><th scope="row"><span ${A('savings.rowSub')}>${t('savings.rowSub')}</span><small class="mono" ${A('savings.rowSubSub')}>${t('savings.rowSubSub')}</small></th><td class="mono strike" data-money="${s.sub1}">$${s.sub1.toFixed(2)}</td><td class="mono strike" data-money="${s.sub3}">$${s.sub3.toFixed(2)}</td></tr>
          <tr class="save"><th scope="row"><span ${A('savings.rowSave')}>${t('savings.rowSave')}</span></th><td class="mono" data-money="${s.save1}">$${s.save1.toFixed(2)}</td><td class="mono" data-money="${s.save3}">$${s.save3.toFixed(2)}</td></tr>
        </tbody>
      </table>
    </div>
    <p class="foot mono" data-reveal ${A('savings.footnote')}>${t('savings.footnote')}</p>
  </div>
</section>

<!-- ═══ PRICING ═══ -->
<section class="pricing grid-paper" id="pricing">
  <span id="buy" class="anchor" aria-hidden="true"></span>
  <div class="wrap">
    <header class="sec-head" data-reveal>
      <p class="eyebrow mono" ${A('pricing.eyebrow')}>${t('pricing.eyebrow')}</p>
      <h2 ${A('pricing.h2')}>${t('pricing.h2')}</h2>
      <p class="sec-sub" ${A('pricing.sub')}>${t('pricing.sub')}</p>
    </header>
    <div class="plans">
      <article class="plan" data-reveal style="--i:0">
        <header class="plan-h"><h3 ${A('pricing.personal.name')}>${t('pricing.personal.name')}</h3><span class="chip mono" ${A('pricing.personal.macs')}>${t('pricing.personal.macs')}</span></header>
        <p class="plan-sub" ${A('pricing.personal.sub')}>${t('pricing.personal.sub')}</p>
        <p class="price"><span class="amt">${usd(pr.personal.usd)}</span><span class="per mono" ${A('pricing.oneTime')}>${t('pricing.oneTime')}</span></p>
        <ul class="feat">${feat('personal')}</ul>
        <button type="button" class="btn btn-ghost btn-wide" data-checkout="personal" ${A('pricing.personal.cta')}>${t('pricing.personal.cta')}</button>
      </article>
      <article class="plan plan-pro" data-reveal style="--i:1">
        <span class="flag mono" ${A('pricing.pro.badge')}>${t('pricing.pro.badge')}</span>
        <header class="plan-h"><h3 ${A('pricing.pro.name')}>${t('pricing.pro.name')}</h3><span class="chip mono" ${A('pricing.pro.macs')}>${t('pricing.pro.macs')}</span></header>
        <p class="plan-sub" ${A('pricing.pro.sub')}>${t('pricing.pro.sub')}</p>
        <p class="price"><span class="amt">${usd(pr.pro.usd)}</span><span class="per mono" ${A('pricing.oneTime')}>${t('pricing.oneTime')}</span></p>
        <ul class="feat">${feat('pro')}</ul>
        <label class="bump">
          <input type="checkbox" data-bump>
          <span class="bump-box" aria-hidden="true"></span>
          <span class="bump-txt"><strong ${A('pricing.bumpTitle')}>${t('pricing.bumpTitle')}</strong> <span class="mono bump-p" ${A('pricing.bumpPrice')}>${t('pricing.bumpPrice')}</span><small ${A('pricing.bumpBody')}>${t('pricing.bumpBody')}</small></span>
        </label>
        <p class="total mono"><span ${A('pricing.total')}>${t('pricing.total')}</span> <span data-total data-base="${pr.pro.usd}" data-bump-price="${pr.findaroBump.usd}">${usd(pr.pro.usd)}</span></p>
        <button type="button" class="btn btn-key btn-wide" data-checkout="pro" ${A('pricing.pro.cta')}>${t('pricing.pro.cta')}</button>
      </article>
      <aside class="trial" data-reveal style="--i:2">
        <p class="trial-n mono">14</p>
        <h3 ${A('pricing.trialTitle')}>${t('pricing.trialTitle')}</h3>
        <p ${A('pricing.trialBody')}>${t('pricing.trialBody')}</p>
        <button type="button" class="btn btn-ink btn-wide" data-open-download ${A('pricing.trialCta')}>${t('pricing.trialCta')}</button>
        <p class="req mono" ${A('pricing.requirements')}>${t('pricing.requirements')}</p>
      </aside>
    </div>
  </div>
</section>

<!-- ═══ FAQ ═══ -->
<section class="faq" id="faq">
  <div class="wrap faq-grid">
    <header class="sec-head" data-reveal>
      <p class="eyebrow mono" ${A('faq.eyebrow')}>${t('faq.eyebrow')}</p>
      <h2 ${A('faq.h2')}>${t('faq.h2')}</h2>
    </header>
    <div class="qas">${faq}</div>
  </div>
</section>
</main>

<!-- ═══ FOOTER (cajetín de plano) ═══ -->
<footer class="foot-main">
  <div class="wrap">
    <div class="titleblock mono">
      <div class="tb tb-brand"><img src="${asset('/media/appicon-128.webp')}" width="40" height="40" alt=""><div><strong>StackDock</strong><span ${A('footer.tagline')}>${t('footer.tagline')}</span></div></div>
      <div class="tb"><span class="k">REV</span><span>${funnel.version} · build ${funnel.build}</span></div>
      <div class="tb"><span class="k">macOS</span><span>${funnel.minMacOS} · Universal</span></div>
      <div class="tb"><span class="k" ${A('footer.team')}>${t('footer.team')}</span><span>${funnel.teamId}</span></div>
      <div class="tb tb-sha"><span class="k" ${A('footer.sha')}>${t('footer.sha')}</span><code class="sha ${shaPending ? 'is-pending' : ''}" data-copy="${esc(funnel.sha256)}" tabindex="0" role="button" title="Copy">${esc(funnel.sha256)}</code></div>
      <div class="tb"><span class="k">DRAWN</span><span>BLACK EYE</span></div>
    </div>
    <div class="foot-row">
      <p ${A('footer.made')}>${t('footer.made')}</p>
      <nav class="foot-links mono">
        <button type="button" data-legal="terms" ${A('footer.terms')}>${t('footer.terms')}</button>
        <button type="button" data-legal="privacy" ${A('footer.privacy')}>${t('footer.privacy')}</button>
        <button type="button" data-legal="refund" ${A('footer.refund')}>${t('footer.refund')}</button>
        <a href="mailto:${funnel.supportEmail}">${funnel.supportEmail}</a>
      </nav>
      <p class="mono small" ${A('footer.rights')}>${t('footer.rights')}</p>
    </div>
  </div>
</footer>

<!-- WhatsApp: exclusivo para dudas -->
<a class="wa" data-wa href="https://wa.me/${funnel.whatsapp.e164}?text=${encodeURIComponent(c.whatsapp.prefill)}" target="_blank" rel="noopener" aria-describedby="wa-tip">
  <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true"><path d="M4 18.5V6.5A2.5 2.5 0 0 1 6.5 4h11A2.5 2.5 0 0 1 20 6.5v7a2.5 2.5 0 0 1-2.5 2.5H8.5L4 18.5Z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M8.5 9.5h7M8.5 12.5h4.5" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>
  <span class="wa-txt"><span class="mono wa-n">${funnel.whatsapp.display}</span><span class="wa-tip" id="wa-tip"><span ${A('whatsapp.tip')}>${t('whatsapp.tip')}</span> <span class="wa-more" ${A('whatsapp.tipMore')}>${t('whatsapp.tipMore')}</span></span></span>
</a>

<!-- Modales -->
<dialog class="modal" data-modal="download" aria-labelledby="dl-t">
  <form method="dialog" class="modal-in" data-dl-form novalidate>
    <header class="modal-h"><img src="${asset('/media/appicon-128.webp')}" width="44" height="44" alt=""><div><h3 id="dl-t" ${A('modal.dlTitle')}>${t('modal.dlTitle')}</h3><p ${A('modal.dlBody')}>${t('modal.dlBody')}</p></div><button type="button" class="x" data-close aria-label="${esc(t('modal.close'))}">✕</button></header>
    <label class="field"><span ${A('modal.emailLabel')}>${t('modal.emailLabel')}</span><input type="email" name="email" autocomplete="email" inputmode="email" placeholder="you@studio.com"><small ${A('modal.emailHint')}>${t('modal.emailHint')}</small><small class="err" data-err hidden ${A('modal.emailInvalid')}>${t('modal.emailInvalid')}</small></label>
    <div class="dl-actions">
      <button type="submit" class="btn btn-key" data-dl-go ${A('modal.dlCta')}>${t('modal.dlCta')}</button>
      <button type="button" class="btn btn-text" data-dl-skip ${A('modal.dlSkip')}>${t('modal.dlSkip')}</button>
    </div>
    <p class="demo-note mono" data-dl-demo hidden ${A('modal.demo')}>${t('modal.demo')}</p>
    <dl class="trust mono">
      <div><dt>FILE</dt><dd>${funnel.dmgFileName} · Universal</dd></div>
      <div><dt ${A('modal.teamLabel')}>${t('modal.teamLabel')}</dt><dd>${funnel.teamId}</dd></div>
      <div class="sha-row"><dt ${A('modal.shaLabel')}>${t('modal.shaLabel')}</dt><dd><code class="sha ${shaPending ? 'is-pending' : ''}" data-copy="${esc(funnel.sha256)}" tabindex="0" role="button">${esc(funnel.sha256)}</code>${shaPending ? `<small class="pend" ${A('modal.shaPending')}>${t('modal.shaPending')}</small>` : ''}</dd></div>
    </dl>
    <p class="verify mono"><span ${A('modal.verify')}>${t('modal.verify')}</span><code>shasum -a 256 ~/Downloads/${funnel.dmgFileName}</code></p>
  </form>
</dialog>

<dialog class="modal" data-modal="checkout" aria-labelledby="co-t">
  <div class="modal-in">
    <header class="modal-h"><div><h3 id="co-t" data-co-title></h3></div><button type="button" class="x" data-close aria-label="${esc(t('modal.close'))}">✕</button></header>
    <div data-co-body></div>
  </div>
</dialog>

<dialog class="modal" data-modal="legal" aria-labelledby="lg-t">
  <div class="modal-in">
    <header class="modal-h"><div><h3 id="lg-t" data-legal-title></h3></div><button type="button" class="x" data-close aria-label="${esc(t('modal.close'))}">✕</button></header>
    <div class="legal-body" data-legal-body></div>
  </div>
</dialog>

<span class="sr" aria-live="polite" data-sr></span>
<script type="module" src="${scriptSrc}"></script>
</body>
</html>`;
}
