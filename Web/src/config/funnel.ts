/**
 * StackDock — motor comercial (único archivo que edita marketing).
 * BLACK EYE · Concepto A "Plano de escritorio" (02 Precision Industrial TE)
 *
 * Reglas:
 *  - Cualquier valor que contenga "PENDING" o "REPLACE" pone su bloque en modo demo
 *    etiquetado (nunca se muestra un dato inventado como real).
 *  - `es: Copy` obliga a que EN y ES tengan exactamente las mismas claves.
 */

export const funnel = {
  product: 'StackDock',
  brand: 'BLACK EYE',
  siteUrl: 'https://stackdock.iareal.net',

  // ── Release ────────────────────────────────────────────────
  version: '4.0.7',
  build: 407,
  minMacOS: '13.0+',
  teamId: 'YH6W55MP95',
  dmgUrl: '/download/StackDock-4.0.7.dmg',
  dmgFileName: 'StackDock-4.0.7.dmg',
  sha256: '44913154846a28f01b133d486ebe7d87523e302c3373bfd2f73cbd0ffd141630',

  // ── Embudo ─────────────────────────────────────────────────
  /** POST { plan, addFindaro, locale, customerEmail? } → { url } (Payment Gateway Universal en n8n) */
  checkoutEndpoint: '/api/checkout',
  /** Captura opcional de email en la descarga del trial → secuencia Resend de 14 días */
  trialWebhookUrl: '/api/trial',
  /** ID de YouTube del tutorial. "" o "PENDING_VIDEO_ID" = fachada técnica sin iframe */
  youtubeVideoId: 'PENDING_VIDEO_ID',

  supportEmail: 'stackdock@iareal.net',
  whatsapp: { display: '+52 56 4567 4407', e164: '525645674407' },
  langCookie: 'stackdock-lang',

  trialDays: 14,
  refundDays: 14,
  prices: {
    personal: { usd: 9.99, macs: 1 },
    pro: { usd: 19, macs: 3 },
    findaroBump: { usd: 29, macs: 1, name: 'Findaro Solo' },
  },

  /** Tabla de ahorro: precio público de referencia por Mac/año de una utilidad de Dock por suscripción */
  savings: { referenceYearlyPerMac: 14.99, years: 3, verifiedOn: '2026-11-13' },

  /** Medición propia (captura de telemetría del repo) */
  measurement: { machine: 'Mac mini M4', cpuIdle: '0.0', footprintMB: 32, rssMB: 92.6 },

  /** Ficha técnica del Panel Grande 4.0.6 */
  panel: {
    media: { en: '/media/media_control_panel_en.webp', es: '/media/media_control_panel_es.webp' },
    /** Posición (%) de cada marcador sobre el visor. Ajustar cuando lleguen las capturas reales. */
    callouts: [
      { n: 1, x: 26.7, y: 13.2 },
      { n: 2, x: 69.2, y: 13.2 },
      { n: 3, x: 69.2, y: 27.6 },
      { n: 4, x: 26.7, y: 50.0 },
      { n: 5, x: 26.7, y: 67.1 },
      { n: 6, x: 69.2, y: 56.6 },
    ],
  },

  captures: [
    { src: '/media/media_screen_top.webp', w: 1200, h: 576 },
    { src: '/media/media_screen_bottom.webp', w: 1200, h: 675 },
  ],
} as const;

export type Locale = 'en' | 'es';

export const isPending = (v: string): boolean => !v || /PENDING|REPLACE|example\.com/i.test(v);

export const usd = (n: number): string => `$${Number.isInteger(n) ? n : n.toFixed(2)}`;

const p = funnel.prices;
const sv = funnel.savings;
export const savingsMath = {
  sub1: +(sv.referenceYearlyPerMac * sv.years).toFixed(2),
  sub3: +(sv.referenceYearlyPerMac * sv.years * 3).toFixed(2),
  get save1() { return +(this.sub1 - p.personal.usd).toFixed(2); },
  get save3() { return +(this.sub3 - p.pro.usd).toFixed(2); },
};

const P1 = usd(p.personal.usd);
const P3 = usd(p.pro.usd);
const PB = usd(p.findaroBump.usd);
const REF = usd(sv.referenceYearlyPerMac);

// ─────────────────────────────────────────────────────────────
//  COPY — EN
// ─────────────────────────────────────────────────────────────
const en = {
  meta: {
    title: 'StackDock — A native Dock on every Mac display',
    description:
      `StackDock puts a native Dock on every monitor, gives each Chrome profile its own icon and moves the active window to the next screen with ⌃W. 14-day free trial, no card required. Personal ${P1} · Pro ${P3}, one-time.`,
    ogAlt: 'StackDock elevation drawing: two stacked displays, one Dock each',
  },
  nav: {
    how: 'How it works',
    panel: 'Control Panel',
    proof: 'Measured',
    pricing: 'Pricing',
    faq: 'FAQ',
    download: 'Download',
    skip: 'Skip to content',
  },
  hero: {
    eyebrow: 'v4.0.7 · build 407 · macOS 13+ · Universal',
    h1a: 'The Dock, on the screen',
    h1b: 'you’re actually looking at.',
    sub: 'StackDock draws a native Dock on every monitor, gives each Chrome profile its own icon with its avatar, and sends the active window to the next screen with <kbd>⌃W</kbd>. Swift and AppKit. No screen recording.',
    ctaTrial: 'Download — 14-day free trial',
    ctaBuy: `Buy from ${P1}`,
    micro: `14-day free trial, no card required · Personal ${P1} (1 Mac) · Pro ${P3} (3 Macs) · one-time`,
    figLabel: 'FIG. 01 — ELEVATION · STACKED DESK',
    figNote: 'Example layout · live simulation of the app’s own math',
    displayTop: 'DISPLAY 1 · 27″ · 2560×1440 pt · main',
    displayBottom: 'DISPLAY 2 · 15.6″ · 1920×1080 pt',
    appleDock: 'Apple Dock',
    appleDockHidden: 'Apple Dock · autohide-delay 1000',
    ctlPlacement: 'Placement',
    placements: ['Bottom', 'Bottom elevated', 'Top', 'Auto per display'],
    placementShort: ['BTM', 'ELEV', 'TOP', 'AUTO'],
    placementNotes: [
      'Bottom · bar sits 6 pt above the screen edge, like Apple’s.',
      'Bottom elevated · 24 pt up, so the pointer doesn’t slip onto the display below when you reach for it.',
      'Top · under the menu bar, 8 pt below the visible frame.',
      'Auto · elevated on the main display, top on every extra display.',
    ],
    ctlIsolate: 'Docks',
    isolateOff: 'Mirror',
    isolateOn: 'Isolate',
    ctlMode: 'Apple Dock',
    modeSolo: 'Solo',
    modeDual: 'Dual',
    ctlSplit: 'Chrome profiles',
    splitOff: 'One icon',
    splitOn: 'Split',
    ctlKey: 'Move window',
    keyHintMac: 'Press ⌃W on your keyboard, or the key',
    keyHintOther: 'Press the key',
    shiftHint: 'Tip: Shift-click a Dock icon to pull its window to that screen.',
    activeLabel: 'Active window',
    readoutIdle: 'READY · select a window, then ⌃W',
    readoutMove: 'MOVE',
    readoutSummon: 'SUMMON',
    readoutState: 'STATE',
    winWork: 'Chrome — Work',
    winClient: 'Chrome — Client',
    winPersonal: 'Chrome — Personal',
    winCursor: 'Cursor — app.swift',
    srMoved: 'Window moved to display',
  },
  how: {
    eyebrow: '§ 02 — How it works',
    h2: 'Three engines. Nothing running when the Dock is hidden.',
    steps: [
      {
        kicker: '01 — Dock per display',
        title: 'A real Dock on every monitor you choose.',
        pain: 'macOS pins the Dock to one screen. On a stacked desk, that’s the screen you’re not looking at.',
        body: 'StackDock puts a native glass bar on each display. Mirror the same apps everywhere, or isolate them: each Dock shows only the windows whose center sits on that screen.',
        specs: [
          ['Material', 'NSVisualEffectView · .hudWindow'],
          ['Bar', '58 pt (38 pt icons + 20)'],
          ['Corner · border', '16 pt · 0.8 pt'],
          ['Placements', '6 pt · 24 pt anti-cross · top · auto'],
          ['Rebuild debounce', '100 ms'],
          ['Solo mode', 'Apple Dock autohide-delay 1000, restored on quit'],
        ],
      },
      {
        kicker: '02 — Profiles, split',
        title: 'One icon per Chrome profile. With its avatar.',
        pain: 'Three Chrome profiles, one icon. You click it and get the wrong one.',
        body: 'With two or more windows open, Chrome, Brave and Edge get one icon per profile using the real profile picture. Safari, Arc, Cursor and VS Code split per window with a short label from the title.',
        specs: [
          ['Avatars', 'Chrome · Brave · Edge'],
          ['Source', 'Local State + Full Disk Access (optional)'],
          ['Per window', 'Safari · Arc · Cursor · VS Code'],
          ['Split threshold', '≥ 2 windows'],
          ['Label', '≤ 14 characters'],
          ['Close one profile', '⌥⌘-click'],
        ],
      },
      {
        kicker: '03 — ⌃W teleport',
        title: 'The window goes where your eyes are.',
        pain: 'The window opened on the other monitor. Again.',
        body: '<kbd>⌃W</kbd> sends the focused window to the next display, keeping its relative position and size. Shift-click a Dock icon to pull that window to the screen you’re on.',
        specs: [
          ['Hotkey', '⌃W (or ⌃⌥W · ⌃⇧W · ⌥W)'],
          ['Target', 'next display · (index + 1) mod count'],
          ['Size', 'proportional · min 35 % of target'],
          ['AX write order', 'size → position → size'],
          ['Permission', 'Accessibility only'],
          ['Show / hide Docks', '⌥D (or ⌃⌥D · ⌘⇧D · F12)'],
        ],
      },
    ],
  },
  panel: {
    eyebrow: '§ 03 — New in 4.0.6',
    h2: 'The Control Panel. Spec sheet ①–⑥.',
    sub: 'Everything that used to live in the menu bar menu, on one large panel.',
    pending: 'Wireframe · real 4.0.6 capture loads here when published',
    figLabel: 'FIG. 03 — CONTROL PANEL 4.0.6',
    callouts: [
      { title: 'Display map', body: 'Pick which monitors draw a Dock, and the 4 real placements: bottom, elevated, top, auto.' },
      { title: 'Solo vs Dual', body: 'Solo hides Apple’s Dock and restores it on quit. Dual keeps both.' },
      { title: 'Profiles', body: 'Real avatars for Chrome, Brave and Edge. Per-window icons for Cursor, VS Code, Arc and Safari.' },
      { title: 'Findaro', body: 'Downloads and Trash tiles open in Findaro when it’s installed. Switch back to Finder any time.' },
      { title: 'Global shortcuts', body: '⌥D shows the Docks. ⌃W moves the window, proportional, never under 35 % of the target screen.' },
      { title: 'Privacy & license', body: '0 Screen Recording permissions. License status verified on-device with Ed25519.' },
    ],
  },
  video: {
    eyebrow: '§ 04 — Tutorial',
    h2: 'Install to first ⌃W in under three minutes.',
    play: 'Play tutorial',
    pendingTitle: 'Tutorial video ships with 4.0.6',
    pendingBody: 'Until then, these are the exact steps the video follows:',
    steps: [
      'Open StackDock-4.0.6.dmg and drag StackDock into Applications.',
      'Launch it. There’s no main window: it lives in the menu bar.',
      'Grant Accessibility when macOS asks (System Settings → Privacy & Security).',
      'Press ⌥D. A Dock appears on every selected display.',
      'Click a window on another screen and press ⌃W.',
    ],
    privacy: 'Loads from youtube-nocookie.com only after you press play.',
  },
  proof: {
    eyebrow: '§ 05 — Measured, not promised',
    h2: 'It listens for events. It never watches your screen.',
    stats: [
      { value: '0', unit: '', label: 'Screen Recording permissions requested' },
      { value: '0.0', unit: '%', label: 'CPU at idle*' },
      { value: '32', unit: 'MB', label: 'memory footprint*' },
    ],
    bullets: [
      ['Network', 'Signed update feed only. No telemetry, no account.'],
      ['License', 'Ed25519 signature verified on the Mac. No activation server.'],
      ['Binary', 'Universal Swift (arm64 + x86_64). No Electron, no runtime.'],
      ['Distribution', 'Developer ID signed and notarized by Apple.'],
    ],
    footnote:
      '* Our own measurement on a Mac mini M4 at idle. The same capture reports 92.6 MB RSS, which also counts shared system frameworks. Your numbers will vary with apps and displays.',
    capturesLabel: 'Real captures, not renders',
    captures: ['Top display: StackDock bar with Activity Monitor open.', 'Lower display: full StackDock bar with Downloads and Trash.'],
  },
  savings: {
    eyebrow: '§ 06 — Three-year cost',
    h2: 'Pay once. Then stop paying.',
    colItem: '',
    col1: '1 Mac',
    col3: '3 Macs',
    rowUs: 'StackDock, one-time',
    rowUsSub: 'Personal · Pro',
    rowSub: 'Subscription Dock utility',
    rowSubSub: `reference ${REF} / year per Mac × 3 years`,
    rowSave: 'You keep',
    footnote:
      'Reference: public yearly price per Mac of a subscription Dock utility, checked on Nov 13, 2026. Price comparison only, not a feature-for-feature one. Third-party prices change.',
  },
  pricing: {
    eyebrow: '§ 07 — License',
    h2: 'One payment. Your Mac, your key.',
    sub: 'Offline license, no account, no subscription. 14-day refund.',
    oneTime: 'USD · one-time',
    personal: {
      name: 'Personal',
      macs: '1 Mac',
      sub: 'One Mac, every feature, every monitor.',
      features: ['All features, unlimited displays', 'Profile splitter + ⌃W teleport', 'Offline Ed25519 key (SDOCK-…) by email', 'Updates through the signed in-app updater'],
      cta: `Buy Personal — ${P1}`,
    },
    pro: {
      name: 'Pro',
      macs: 'Up to 3 Macs',
      sub: 'For the desk, the laptop and the studio machine.',
      features: ['Everything in Personal', 'Valid on up to 3 Macs', 'Priority support by email', 'Optional Findaro add-on below'],
      cta: `Buy Pro — ${P3}`,
      badge: 'Best value',
    },
    bumpTitle: 'Add Findaro Solo',
    bumpBody: 'Dual-pane file manager for Mac, 1 Mac license. Opens from StackDock’s Downloads and Trash tiles.',
    bumpPrice: `+${PB}`,
    total: 'Total',
    trialTitle: '14-day free trial, no card required.',
    trialBody: 'Every feature unlocked. On day 15 the StackDock Docks pause and the app asks for a key. Buying doesn’t require a reinstall.',
    trialCta: 'Download free trial',
    requirements: 'macOS 13+ · Apple Silicon or Intel · Accessibility permission',
  },
  faq: {
    eyebrow: '§ 08 — Questions',
    h2: 'Before you download.',
    items: [
      { q: 'Does it need Screen Recording?', a: 'No. StackDock reads windows through the Accessibility API and listens to system notifications. It never captures your screen, so macOS never asks for that permission.' },
      { q: 'Does it replace Apple’s Dock?', a: 'Your call. Solo hides Apple’s Dock (autohide with a 1000-second delay) and restores your original settings when you quit. Dual keeps both.' },
      { q: 'Which browsers show profile avatars?', a: 'Chrome, Brave and Edge. Reading profile names and pictures needs Full Disk Access once; it’s optional. Safari, Arc, Cursor and VS Code split per window with a label from the title.' },
      { q: 'How many Macs can I use?', a: 'Personal covers 1 Mac, Pro up to 3. The key is checked offline on your Mac: no account, no activation server.' },
      { q: 'What happens after 14 days?', a: 'The StackDock Docks pause and the app asks for your key. Paste the SDOCK-… key from your email and everything comes back, no reinstall.' },
      { q: 'Can I get a refund?', a: 'Yes, within 14 days of purchase. Email stackdock@iareal.net with your receipt email and order ID. The key for that order is revoked.' },
      { q: 'Apple Silicon or Intel?', a: 'Both. It’s a single universal binary for macOS 13 Ventura or later.' },
      { q: 'How do updates work?', a: 'The app checks an Ed25519-signed feed, verifies the SHA-256 and the download host, then replaces itself in place.' },
      { q: 'What’s the Findaro connection?', a: 'If Findaro is installed, the Downloads and Trash tiles open in it. You can switch them back to Finder. Findaro Solo is an optional add-on in the Pro checkout.' },
    ],
  },
  footer: {
    tagline: 'One Dock. Every display.',
    made: 'Built in Swift by BLACK EYE.',
    terms: 'Terms',
    privacy: 'Privacy',
    refund: '14-day refund',
    sha: 'SHA-256',
    team: 'Apple Team ID',
    rights: '© 2026 BLACK EYE. StackDock is proprietary software.',
  },
  whatsapp: {
    label: 'WhatsApp',
    tip: 'Exclusive for questions',
    tipMore: '(licenses & refunds: stackdock@iareal.net)',
    prefill: 'Hi, I have a question about StackDock:',
  },
  modal: {
    close: 'Close',
    dlTitle: 'Download StackDock 4.0.6',
    dlBody: 'Universal installer, signed and notarized by Apple. 14-day free trial, no card required.',
    emailLabel: 'Email for setup tips (optional)',
    emailHint: 'A short 14-day sequence. Skip it if you like.',
    emailInvalid: 'That email doesn’t look right.',
    dlCta: 'Download .dmg',
    dlSkip: 'Download without email',
    shaLabel: 'SHA-256',
    shaPending: 'Pending · published with the notarized build',
    teamLabel: 'Apple Team ID',
    verify: 'Verify after downloading:',
    copy: 'Copy',
    copied: 'Copied',
    demo: 'Demo mode: the trial webhook isn’t configured yet, so no email is sent.',
    coLoading: 'Opening secure checkout…',
    coError: 'Checkout didn’t respond. Try again, or email stackdock@iareal.net and we’ll send a payment link.',
    coDemoTitle: 'Checkout · demo mode',
    coDemoBody: 'This preview has no backend. In production the button sends this to POST /api/checkout and redirects to the returned URL:',
    retry: 'Try again',
  },
  legal: {
    terms: { title: 'Terms of Service', body: '<p>StackDock is a macOS utility sold by BLACK EYE. A Personal license covers 1 Mac; Pro covers up to 3 Macs. Licenses are delivered as offline Ed25519 keys (SDOCK-…) after payment.</p><p>You may not redistribute the binary or license keys. The software is provided as-is for personal or internal business use on authorized Macs.</p><p>Contact: <a href="mailto:stackdock@iareal.net">stackdock@iareal.net</a></p>' },
    privacy: { title: 'Privacy Policy', body: '<p>We collect only what is needed to fulfill purchases and optional trial onboarding: checkout email, optional trial email and license delivery metadata.</p><p>StackDock validates licenses offline on-device; there is no account and no continuous cloud check-in. The app contacts the network only for the signed update feed.</p><p>Emails are sent via Resend. Payments are processed by Stripe. Support: stackdock@iareal.net · WhatsApp +52 56 4567 4407 (questions only).</p>' },
    refund: { title: '14-Day Refund Policy', body: '<p>If StackDock does not work as described on a supported Mac (macOS 13+), email <a href="mailto:stackdock@iareal.net">stackdock@iareal.net</a> within 14 days of purchase for a full refund.</p><p>Include your receipt email and order ID. License keys associated with refunded orders are revoked.</p>' },
  },
};

export type Copy = typeof en;

// ─────────────────────────────────────────────────────────────
//  COPY — ES
// ─────────────────────────────────────────────────────────────
const es: Copy = {
  meta: {
    title: 'StackDock — Un Dock nativo en cada pantalla de tu Mac',
    description:
      `StackDock pone un Dock nativo en cada monitor, le da a cada perfil de Chrome su propio icono y mueve la ventana activa a la siguiente pantalla con ⌃W. Prueba gratuita de 14 días sin tarjeta. Personal ${P1} · Pro ${P3}, pago único.`,
    ogAlt: 'Plano de StackDock: dos pantallas apiladas, un Dock en cada una',
  },
  nav: {
    how: 'Cómo funciona',
    panel: 'Panel de Control',
    proof: 'Medido',
    pricing: 'Precio',
    faq: 'Preguntas',
    download: 'Descargar',
    skip: 'Saltar al contenido',
  },
  hero: {
    eyebrow: 'v4.0.6 · build 406 · macOS 13+ · Universal',
    h1a: 'El Dock, en la pantalla',
    h1b: 'que estás mirando.',
    sub: 'StackDock dibuja un Dock nativo en cada monitor, le da a cada perfil de Chrome su propio icono con avatar y manda la ventana activa a la siguiente pantalla con <kbd>⌃W</kbd>. Swift y AppKit. Sin grabación de pantalla.',
    ctaTrial: 'Descargar — prueba de 14 días',
    ctaBuy: `Comprar desde ${P1}`,
    micro: `Prueba gratuita de 14 días sin tarjeta · Personal ${P1} (1 Mac) · Pro ${P3} (3 Macs) · pago único`,
    figLabel: 'FIG. 01 — ALZADO · ESCRITORIO APILADO',
    figNote: 'Disposición de ejemplo · simulación en vivo con la matemática de la app',
    displayTop: 'PANTALLA 1 · 27″ · 2560×1440 pt · principal',
    displayBottom: 'PANTALLA 2 · 15,6″ · 1920×1080 pt',
    appleDock: 'Dock de Apple',
    appleDockHidden: 'Dock de Apple · autohide-delay 1000',
    ctlPlacement: 'Posición',
    placements: ['Abajo', 'Abajo elevado', 'Arriba', 'Auto por pantalla'],
    placementShort: ['ABAJ', 'ELEV', 'ARRI', 'AUTO'],
    placementNotes: [
      'Abajo · la barra queda 6 pt sobre el borde, como la de Apple.',
      'Abajo elevado · 24 pt arriba, para que el puntero no se escape a la pantalla de abajo al buscarla.',
      'Arriba · bajo la barra de menús, 8 pt por debajo del área visible.',
      'Auto · elevado en la pantalla principal, arriba en cada pantalla extra.',
    ],
    ctlIsolate: 'Docks',
    isolateOff: 'Espejo',
    isolateOn: 'Aislado',
    ctlMode: 'Dock de Apple',
    modeSolo: 'Solo',
    modeDual: 'Dual',
    ctlSplit: 'Perfiles de Chrome',
    splitOff: 'Un icono',
    splitOn: 'Separados',
    ctlKey: 'Mover ventana',
    keyHintMac: 'Pulsa ⌃W en tu teclado, o la tecla',
    keyHintOther: 'Pulsa la tecla',
    shiftHint: 'Truco: Shift-clic en un icono del Dock trae su ventana a esa pantalla.',
    activeLabel: 'Ventana activa',
    readoutIdle: 'LISTO · elige una ventana y pulsa ⌃W',
    readoutMove: 'MOVER',
    readoutSummon: 'TRAER',
    readoutState: 'ESTADO',
    winWork: 'Chrome — Trabajo',
    winClient: 'Chrome — Cliente',
    winPersonal: 'Chrome — Personal',
    winCursor: 'Cursor — app.swift',
    srMoved: 'Ventana movida a la pantalla',
  },
  how: {
    eyebrow: '§ 02 — Cómo funciona',
    h2: 'Tres motores. Nada corriendo cuando el Dock está oculto.',
    steps: [
      {
        kicker: '01 — Dock por pantalla',
        title: 'Un Dock de verdad en cada monitor que elijas.',
        pain: 'macOS ancla el Dock a una sola pantalla. En un escritorio apilado, justo la que no estás mirando.',
        body: 'StackDock pone una barra de cristal nativa en cada pantalla. Repite las mismas apps en todas o aíslalas: cada Dock muestra solo las ventanas cuyo centro está en esa pantalla.',
        specs: [
          ['Material', 'NSVisualEffectView · .hudWindow'],
          ['Barra', '58 pt (iconos 38 pt + 20)'],
          ['Esquina · borde', '16 pt · 0,8 pt'],
          ['Posiciones', '6 pt · 24 pt anti-cruce · arriba · auto'],
          ['Debounce de reconstrucción', '100 ms'],
          ['Modo Solo', 'Dock de Apple con autohide-delay 1000, restaurado al salir'],
        ],
      },
      {
        kicker: '02 — Perfiles separados',
        title: 'Un icono por perfil de Chrome. Con su avatar.',
        pain: 'Tres perfiles de Chrome, un solo icono. Le das clic y sale el que no era.',
        body: 'Con dos o más ventanas abiertas, Chrome, Brave y Edge muestran un icono por perfil con la foto real del perfil. Safari, Arc, Cursor y VS Code se separan por ventana con una etiqueta corta sacada del título.',
        specs: [
          ['Avatares', 'Chrome · Brave · Edge'],
          ['Origen', 'Local State + Acceso total al disco (opcional)'],
          ['Por ventana', 'Safari · Arc · Cursor · VS Code'],
          ['Umbral', '≥ 2 ventanas'],
          ['Etiqueta', '≤ 14 caracteres'],
          ['Cerrar un perfil', '⌥⌘-clic'],
        ],
      },
      {
        kicker: '03 — Teletransporte ⌃W',
        title: 'La ventana va a donde miras.',
        pain: 'La ventana se abrió en el otro monitor. Otra vez.',
        body: '<kbd>⌃W</kbd> manda la ventana activa a la siguiente pantalla conservando su posición y tamaño relativos. Shift-clic en un icono del Dock trae esa ventana a la pantalla donde estás.',
        specs: [
          ['Atajo', '⌃W (o ⌃⌥W · ⌃⇧W · ⌥W)'],
          ['Destino', 'siguiente pantalla · (índice + 1) mod total'],
          ['Tamaño', 'proporcional · mínimo 35 % del destino'],
          ['Orden de escritura AX', 'tamaño → posición → tamaño'],
          ['Permiso', 'solo Accesibilidad'],
          ['Mostrar / ocultar Docks', '⌥D (o ⌃⌥D · ⌘⇧D · F12)'],
        ],
      },
    ],
  },
  panel: {
    eyebrow: '§ 03 — Nuevo en 4.0.6',
    h2: 'El Panel de Control. Ficha técnica ①–⑥.',
    sub: 'Todo lo que antes vivía en el menú de la barra, en un solo panel grande.',
    pending: 'Wireframe · aquí carga la captura real de 4.0.6 al publicarse',
    figLabel: 'FIG. 03 — PANEL DE CONTROL 4.0.6',
    callouts: [
      { title: 'Mapa de pantallas', body: 'Elige qué monitores dibujan Dock y las 4 posiciones reales: abajo, elevado, arriba y auto.' },
      { title: 'Solo vs Dual', body: 'Solo oculta el Dock de Apple y lo restaura al salir. Dual mantiene los dos.' },
      { title: 'Perfiles', body: 'Avatares reales en Chrome, Brave y Edge. Iconos por ventana en Cursor, VS Code, Arc y Safari.' },
      { title: 'Findaro', body: 'Las casillas de Descargas y Papelera abren en Findaro si está instalado. Puedes volver a Finder cuando quieras.' },
      { title: 'Atajos globales', body: '⌥D muestra los Docks. ⌃W mueve la ventana, proporcional y nunca por debajo del 35 % de la pantalla destino.' },
      { title: 'Privacidad y licencia', body: '0 permisos de Grabación de pantalla. Estado de la licencia verificado en la Mac con Ed25519.' },
    ],
  },
  video: {
    eyebrow: '§ 04 — Tutorial',
    h2: 'De instalar a tu primer ⌃W en menos de tres minutos.',
    play: 'Reproducir tutorial',
    pendingTitle: 'El video tutorial llega con 4.0.6',
    pendingBody: 'Mientras tanto, estos son los pasos exactos que sigue el video:',
    steps: [
      'Abre StackDock-4.0.6.dmg y arrastra StackDock a Aplicaciones.',
      'Ábrelo. No tiene ventana principal: vive en la barra de menús.',
      'Concede Accesibilidad cuando macOS lo pida (Ajustes del Sistema → Privacidad y seguridad).',
      'Pulsa ⌥D. Aparece un Dock en cada pantalla seleccionada.',
      'Haz clic en una ventana de otra pantalla y pulsa ⌃W.',
    ],
    privacy: 'Carga desde youtube-nocookie.com solo cuando pulsas reproducir.',
  },
  proof: {
    eyebrow: '§ 05 — Medido, no prometido',
    h2: 'Escucha eventos. Nunca mira tu pantalla.',
    stats: [
      { value: '0', unit: '', label: 'permisos de Grabación de pantalla' },
      { value: '0.0', unit: '%', label: 'CPU en reposo*' },
      { value: '32', unit: 'MB', label: 'footprint de memoria*' },
    ],
    bullets: [
      ['Red', 'Solo el feed firmado de actualizaciones. Sin telemetría ni cuentas.'],
      ['Licencia', 'Firma Ed25519 verificada en la Mac. Sin servidor de activación.'],
      ['Binario', 'Swift universal (arm64 + x86_64). Sin Electron ni runtimes.'],
      ['Distribución', 'Firmado con Developer ID y notarizado por Apple.'],
    ],
    footnote:
      '* Medición propia en un Mac mini M4 en reposo. La misma captura marca 92,6 MB de RSS, que también cuenta frameworks compartidos del sistema. Tus cifras variarán según apps y pantallas.',
    capturesLabel: 'Capturas reales, no renders',
    captures: ['Pantalla superior: barra de StackDock con el Monitor de Actividad abierto.', 'Pantalla inferior: barra completa de StackDock con Descargas y Papelera.'],
  },
  savings: {
    eyebrow: '§ 06 — Costo a tres años',
    h2: 'Pagas una vez. Y dejas de pagar.',
    colItem: '',
    col1: '1 Mac',
    col3: '3 Macs',
    rowUs: 'StackDock, pago único',
    rowUsSub: 'Personal · Pro',
    rowSub: 'Utilidad de Dock por suscripción',
    rowSubSub: `referencia ${REF} / año por Mac × 3 años`,
    rowSave: 'Te ahorras',
    footnote:
      'Referencia: precio público anual por Mac de una utilidad de Dock por suscripción, consultado el 13 de noviembre de 2026. Solo compara precio, no funciones. Los precios de terceros cambian.',
  },
  pricing: {
    eyebrow: '§ 07 — Licencia',
    h2: 'Un pago. Tu Mac, tu clave.',
    sub: 'Licencia offline, sin cuenta ni suscripción. Reembolso en 14 días.',
    oneTime: 'USD · pago único',
    personal: {
      name: 'Personal',
      macs: '1 Mac',
      sub: 'Una Mac, todas las funciones, todos los monitores.',
      features: ['Todas las funciones, pantallas ilimitadas', 'Separador de perfiles + teletransporte ⌃W', 'Clave offline Ed25519 (SDOCK-…) por email', 'Actualizaciones con el actualizador firmado de la app'],
      cta: `Comprar Personal — ${P1}`,
    },
    pro: {
      name: 'Pro',
      macs: 'Hasta 3 Macs',
      sub: 'Para el escritorio, la laptop y la Mac del estudio.',
      features: ['Todo lo de Personal', 'Válida hasta en 3 Macs', 'Soporte prioritario por email', 'Complemento Findaro opcional abajo'],
      cta: `Comprar Pro — ${P3}`,
      badge: 'Mejor valor',
    },
    bumpTitle: 'Añadir Findaro Solo',
    bumpBody: 'Gestor de archivos de doble panel para Mac, licencia para 1 Mac. Se abre desde las casillas de Descargas y Papelera de StackDock.',
    bumpPrice: `+${PB}`,
    total: 'Total',
    trialTitle: 'Prueba gratuita de 14 días sin tarjeta.',
    trialBody: 'Todas las funciones activas desde el primer día. El día 15 los Docks de StackDock se pausan y la app te pide una clave. Comprar no requiere reinstalar.',
    trialCta: 'Descargar prueba gratis',
    requirements: 'macOS 13+ · Apple Silicon o Intel · permiso de Accesibilidad',
  },
  faq: {
    eyebrow: '§ 08 — Preguntas',
    h2: 'Antes de descargar.',
    items: [
      { q: '¿Necesita Grabación de pantalla?', a: 'No. StackDock lee las ventanas con la API de Accesibilidad y escucha notificaciones del sistema. Nunca captura tu pantalla, así que macOS nunca pide ese permiso.' },
      { q: '¿Reemplaza el Dock de Apple?', a: 'Tú decides. Solo oculta el Dock de Apple (autohide con 1000 segundos de retraso) y restaura tu configuración original al salir. Dual mantiene los dos.' },
      { q: '¿Qué navegadores muestran avatares?', a: 'Chrome, Brave y Edge. Para leer nombres y fotos de perfil hace falta Acceso total al disco una vez; es opcional. Safari, Arc, Cursor y VS Code se separan por ventana con una etiqueta del título.' },
      { q: '¿En cuántas Macs puedo usarlo?', a: 'Personal cubre 1 Mac y Pro hasta 3. La clave se verifica offline en tu Mac: sin cuenta y sin servidor de activación.' },
      { q: '¿Qué pasa después de 14 días?', a: 'Los Docks de StackDock se pausan y la app te pide la clave. Pega la clave SDOCK-… de tu correo y todo vuelve, sin reinstalar.' },
      { q: '¿Puedo pedir reembolso?', a: 'Sí, dentro de los 14 días posteriores a la compra. Escribe a stackdock@iareal.net con el email del recibo y el número de orden. La clave de esa orden se revoca.' },
      { q: '¿Apple Silicon o Intel?', a: 'Ambos. Es un solo binario universal para macOS 13 Ventura o posterior.' },
      { q: '¿Cómo se actualiza?', a: 'La app consulta un feed firmado con Ed25519, verifica el SHA-256 y el servidor de descarga, y se reemplaza a sí misma.' },
      { q: '¿Qué relación tiene con Findaro?', a: 'Si Findaro está instalado, las casillas de Descargas y Papelera se abren en él. Puedes volver a Finder. Findaro Solo es un complemento opcional en el checkout de Pro.' },
    ],
  },
  footer: {
    tagline: 'Un Dock. Cada pantalla.',
    made: 'Hecho en Swift por BLACK EYE.',
    terms: 'Términos',
    privacy: 'Privacidad',
    refund: 'Reembolso 14 días',
    sha: 'SHA-256',
    team: 'Apple Team ID',
    rights: '© 2026 BLACK EYE. StackDock es software propietario.',
  },
  whatsapp: {
    label: 'WhatsApp',
    tip: 'Exclusivo para dudas',
    tipMore: '(licencias y reembolsos: stackdock@iareal.net)',
    prefill: 'Hola, tengo una duda sobre StackDock:',
  },
  modal: {
    close: 'Cerrar',
    dlTitle: 'Descargar StackDock 4.0.6',
    dlBody: 'Instalador universal, firmado y notarizado por Apple. Prueba gratuita de 14 días sin tarjeta.',
    emailLabel: 'Email para tips de configuración (opcional)',
    emailHint: 'Una secuencia corta de 14 días. Puedes omitirlo.',
    emailInvalid: 'Ese email no parece correcto.',
    dlCta: 'Descargar .dmg',
    dlSkip: 'Descargar sin email',
    shaLabel: 'SHA-256',
    shaPending: 'Pendiente · se publica con el build notarizado',
    teamLabel: 'Apple Team ID',
    verify: 'Verifica después de descargar:',
    copy: 'Copiar',
    copied: 'Copiado',
    demo: 'Modo demo: el webhook del trial aún no está configurado, no se envía ningún email.',
    coLoading: 'Abriendo el checkout seguro…',
    coError: 'El checkout no respondió. Inténtalo de nuevo o escribe a stackdock@iareal.net y te enviamos un link de pago.',
    coDemoTitle: 'Checkout · modo demo',
    coDemoBody: 'Esta vista previa no tiene backend. En producción el botón envía esto a POST /api/checkout y redirige a la URL devuelta:',
    retry: 'Reintentar',
  },
  legal: {
    terms: { title: 'Términos del servicio', body: '<p>StackDock es una utilidad para macOS vendida por BLACK EYE. La licencia Personal cubre 1 Mac; Pro cubre hasta 3 Macs. Las licencias se entregan como claves offline Ed25519 (SDOCK-…) tras el pago.</p><p>No puedes redistribuir el binario ni las claves. El software se entrega tal cual para uso personal o interno de empresa en Macs autorizadas.</p><p>Contacto: <a href="mailto:stackdock@iareal.net">stackdock@iareal.net</a></p>' },
    privacy: { title: 'Política de privacidad', body: '<p>Solo recopilamos lo necesario para completar compras y el onboarding opcional del trial: email del checkout, email opcional del trial y datos de entrega de la licencia.</p><p>StackDock valida la licencia offline en tu Mac; no hay cuenta ni verificación continua en la nube. La app solo se conecta a la red para el feed firmado de actualizaciones.</p><p>Los correos se envían con Resend. Los pagos los procesa Stripe. Soporte: stackdock@iareal.net · WhatsApp +52 56 4567 4407 (solo dudas).</p>' },
    refund: { title: 'Política de reembolso de 14 días', body: '<p>Si StackDock no funciona como se describe en una Mac compatible (macOS 13+), escribe a <a href="mailto:stackdock@iareal.net">stackdock@iareal.net</a> dentro de los 14 días posteriores a la compra para un reembolso completo.</p><p>Incluye el email del recibo y el número de orden. Las claves de órdenes reembolsadas se revocan.</p>' },
  },
};

export const copy: Record<Locale, Copy> = { en, es };
