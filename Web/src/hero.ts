/**
 * Hero vivo — simulador del alzado con la matemática real de StackDock:
 *  · WindowTeleportAndProfileService.moveWindow  (relX/relY clamp 0…1, relW/relH clamp 0.35…1,
 *    origen = dst.x + relX·(dst.w − newW), escritura AX size → position → size)
 *  · smartSummonOrNextMonitor (Shift-clic)
 *  · moveFrontmostWindowToNextMonitor  ((idx + 1) % pantallas)
 *  · layoutDock: barH = icon + 20, tileW = icon + 12, spacing 3, pad 8, divider 11,
 *    originY = +6 (bottom) · +24 (elevated) · visibleFrame.maxY − barH − 8 (top)
 *  · buildTileEntries: aislado = ventana cuyo centro está en la pantalla; split si ≥ 2 ventanas
 */
import { copy, type Copy } from './config/funnel';
import { currentLocale } from './i18n';

type Profile = 'work' | 'client' | 'personal';
interface Win { id: string; app: 'chrome' | 'cursor'; profile?: Profile; screen: number; x: number; y: number; w: number; h: number; key: keyof Copy['hero'] }
interface Tile { app: string; color: string; glyph: string; running: boolean; win?: Win; avatar?: { l: string; c: string }; special?: 'downloads' | 'trash'; label: string }

const SCREENS = [
  { w: 2560, h: 1440, rect: { l: 10, t: 6.6667, w: 80, h: 48 } }, // principal (Dock de Apple)
  { w: 1920, h: 1080, rect: { l: 20, t: 58.6667, w: 60, h: 36 } },
];
const MENU = 24;
const ICON = 38;
const BAR_H = ICON + 20;
const TILE_W = ICON + 12;
const SPACING = 3;
const PAD = 8;
const DIVIDER = 11;
/** Los Docks se dibujan a 2.2× para que se lean en el plano (indicado en la nota de la figura). */
const VIS = 2.2;
const PROFILE_AV: Record<Profile, { l: string; c: string }> = {
  work: { l: 'W', c: '#10B981' },
  client: { l: 'C', c: '#6366F1' },
  personal: { l: 'P', c: '#F472B6' },
};

const vf = (i: number) => ({ x: 0, y: MENU, w: SCREENS[i].w, h: SCREENS[i].h - MENU });
const clamp = (v: number, a: number, b: number) => Math.max(a, Math.min(b, v));
const r3 = (n: number) => n.toFixed(3);

export function initHero(root: HTMLElement) {
  const $ = <T extends Element = HTMLElement>(s: string) => root.querySelector(s) as T;
  const winLayer = $('[data-winlayer]');
  const dockLayer = $('[data-docklayer]');
  const trace = $<SVGGElement>('[data-trace]');
  const rotary = $('[data-rotary]');
  const keycap = $<HTMLButtonElement>('[data-keycap]');
  const lcd = [1, 2, 3, 4].map((n) => $(`[data-lcd-${n}]`));
  const sr = document.querySelector('[data-sr]') as HTMLElement | null;

  const state = {
    placement: 1,
    isolate: false,
    dual: false,
    split: true,
    active: 'work',
    order: ['personal', 'client', 'cursor', 'work'],
    last: null as null | { kind: 'move' | 'summon' | 'open'; win?: Win; from?: number; to?: number; rel?: number[]; size?: number[]; text?: string },
  };

  const wins: Win[] = [
    { id: 'work', app: 'chrome', profile: 'work', screen: 0, x: 180, y: 130, w: 1400, h: 880, key: 'winWork' },
    { id: 'cursor', app: 'cursor', screen: 0, x: 1460, y: 330, w: 920, h: 760, key: 'winCursor' },
    { id: 'client', app: 'chrome', profile: 'client', screen: 1, x: 140, y: 110, w: 1080, h: 640, key: 'winClient' },
    { id: 'personal', app: 'chrome', profile: 'personal', screen: 1, x: 980, y: 300, w: 800, h: 560, key: 'winPersonal' },
  ];
  const byId = (id: string) => wins.find((w) => w.id === id)!;
  const c = () => copy[currentLocale()].hero;

  // ── Matemática real ────────────────────────────────────────
  function moveWindow(win: Win, dst: number) {
    const s = vf(win.screen);
    const d = vf(dst);
    const relX = clamp((win.x - s.x) / Math.max(1, s.w), 0, 1);
    const relY = clamp((win.y - s.y) / Math.max(1, s.h), 0, 1);
    const relW = clamp(win.w / Math.max(1, s.w), 0.35, 1);
    const relH = clamp(win.h / Math.max(1, s.h), 0.35, 1);
    const nw = Math.round(d.w * relW);
    const nh = Math.round(d.h * relH);
    const nx = Math.round(d.x + relX * (d.w - nw));
    const ny = Math.round(d.y + relY * (d.h - nh));
    const from = win.screen;
    const before = center(win);
    Object.assign(win, { screen: dst, x: nx, y: ny, w: nw, h: nh });
    drawTrace(before, center(win));
    return { from, rel: [relX, relY, relW, relH], size: [nw, nh, nx, ny] };
  }
  function nextScreen(i: number) { return (i + 1) % SCREENS.length; }

  function moveActive() {
    const win = byId(state.active);
    const r = moveWindow(win, nextScreen(win.screen));
    state.last = { kind: 'move', win, from: r.from, to: win.screen, rel: r.rel, size: r.size };
    announce(win);
    render();
  }

  function summon(win: Win, clicked: number) {
    const target = win.screen !== clicked ? clicked : nextScreen(clicked);
    const r = moveWindow(win, target);
    focus(win.id, false);
    state.last = { kind: 'summon', win, from: r.from, to: win.screen, rel: r.rel, size: r.size };
    announce(win);
    render();
  }

  function focus(id: string, doRender = true) {
    state.active = id;
    state.order = state.order.filter((x) => x !== id).concat(id);
    if (doRender) render();
  }

  function announce(win: Win) {
    if (sr) sr.textContent = `${c()[win.key]} — ${c().srMoved} ${win.screen + 1}`;
  }

  // ── Geometría a % del escenario ────────────────────────────
  const toStage = (screen: number, x: number, y: number) => {
    const S = SCREENS[screen];
    return { l: S.rect.l + (x / S.w) * S.rect.w, t: S.rect.t + (y / S.h) * S.rect.h };
  };
  function center(w: Win) {
    const p = toStage(w.screen, w.x + w.w / 2, w.y + w.h / 2);
    return { x: (p.l / 100) * 640, y: (p.t / 100) * 600 };
  }
  function drawTrace(a: { x: number; y: number }, b: { x: number; y: number }) {
    const mid = { x: (a.x + b.x) / 2 + (a.y < b.y ? 40 : -40), y: (a.y + b.y) / 2 };
    const g = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    g.setAttribute('class', 'trace-g');
    g.innerHTML = `<path d="M${a.x} ${a.y} Q ${mid.x} ${mid.y} ${b.x} ${b.y}" class="trace"/><circle cx="${a.x}" cy="${a.y}" r="3" class="t-a"/><circle cx="${b.x}" cy="${b.y}" r="4" class="t-b"/>`;
    trace.replaceChildren(g);
  }

  // ── Docks (buildTileEntries) ───────────────────────────────
  function placementFor(screen: number) {
    if (state.placement !== 3) return state.placement;
    return screen === 0 ? 1 : 2; // auto: elevado en la principal, arriba en extras
  }

  function tilesFor(screen: number): Tile[] {
    const h = c();
    const out: Tile[] = [{ app: 'Finder', color: '#38BDF8', glyph: 'F', running: true, label: 'Finder' }];
    const chromeWins = wins.filter((w) => w.app === 'chrome' && (!state.isolate || w.screen === screen));
    if (chromeWins.length) {
      if (state.split && chromeWins.length >= 2) {
        chromeWins.forEach((w) => out.push({ app: 'Chrome', color: '#FBBF24', glyph: 'C', running: true, win: w, avatar: PROFILE_AV[w.profile!], label: h[w.key] as string }));
      } else {
        const w = chromeWins[0];
        out.push({ app: 'Chrome', color: '#FBBF24', glyph: 'C', running: true, win: w, avatar: state.split || chromeWins.length === 1 ? PROFILE_AV[w.profile!] : undefined, label: 'Google Chrome' });
      }
    }
    const cur = wins.filter((w) => w.app === 'cursor' && (!state.isolate || w.screen === screen));
    if (cur.length) out.push({ app: 'Cursor', color: '#6366F1', glyph: '›', running: true, win: cur[0], label: 'Cursor' });
    if (!state.isolate) out.push({ app: 'Mail', color: '#F472B6', glyph: 'M', running: false, label: 'Mail' });
    out.push({ app: 'Downloads', color: '', glyph: '', running: false, special: 'downloads', label: 'Downloads' });
    out.push({ app: 'Trash', color: '', glyph: '', running: false, special: 'trash', label: 'Trash' });
    return out;
  }

  function renderDock(screen: number) {
    const S = SCREENS[screen];
    const tiles = tilesFor(screen);
    const n = tiles.length;
    const totalW = PAD * 2 + DIVIDER + n * TILE_W + (n - 1) * SPACING;
    const wPt = totalW * VIS;
    const hPt = BAR_H * VIS;
    const xPt = S.w / 2 - wPt / 2;
    const pl = placementFor(screen);
    const yPt = pl === 0 ? S.h - (6 + BAR_H) * VIS : pl === 1 ? S.h - (24 + BAR_H) * VIS : MENU + 8 * VIS;
    const p = toStage(screen, xPt, yPt);
    let el = dockLayer.querySelector<HTMLElement>(`[data-dock="${screen}"]`);
    if (!el) {
      el = document.createElement('div');
      el.className = 'sd-dock';
      el.dataset.dock = String(screen);
      dockLayer.appendChild(el);
    }
    el.style.left = `${p.l}%`;
    el.style.top = `${p.t}%`;
    el.style.width = `${(wPt / S.w) * S.rect.w}%`;
    el.style.height = `${(hPt / S.h) * S.rect.h}%`;
    el.dataset.pl = String(pl);

    let x = PAD;
    const html: string[] = [];
    tiles.forEach((t, i) => {
      if (t.special === 'downloads') {
        html.push(`<span class="div" style="left:${((x + DIVIDER / 2) / totalW) * 100}%"></span>`);
        x += DIVIDER;
      }
      const left = (x / totalW) * 100;
      const w = (TILE_W / totalW) * 100;
      const active = t.win && t.win.id === state.active;
      const cls = ['tile', t.special ? `sp sp-${t.special}` : '', active ? 'is-active' : ''].join(' ');
      html.push(
        `<button type="button" class="${cls}" style="left:${left}%;width:${w}%" data-t="${i}" aria-label="${t.label}" title="${t.label}">` +
          `<span class="ic" ${t.color ? `style="--tc:${t.color}"` : ''}>${t.glyph ? `<b>${t.glyph}</b>` : ''}</span>` +
          (t.avatar ? `<span class="av" style="--ac:${t.avatar.c}">${t.avatar.l}</span>` : '') +
          (t.running ? '<span class="run"></span>' : '') +
          `</button>`,
      );
      x += TILE_W + SPACING;
    });
    el.innerHTML = html.join('');
    el.querySelectorAll<HTMLButtonElement>('.tile').forEach((b) => {
      b.addEventListener('click', (ev) => {
        const t = tiles[Number(b.dataset.t)];
        tilePress(t, screen, ev.shiftKey);
      });
    });
  }

  function tilePress(t: Tile, screen: number, shift: boolean) {
    if (t.special) {
      state.last = { kind: 'open', text: `OPEN ~/${t.special === 'downloads' ? 'Downloads' : '.Trash'} → Findaro (app.findaro.files) · fallback Finder` };
      render();
      return;
    }
    if (!t.win) {
      state.last = { kind: 'open', text: `LAUNCH ${t.app}` };
      render();
      return;
    }
    if (shift) summon(t.win, screen);
    else focus(t.win.id);
  }

  // ── Ventanas ────────────────────────────────────────────────
  function renderWins() {
    const h = c();
    wins.forEach((w) => {
      let el = winLayer.querySelector<HTMLElement>(`[data-win="${w.id}"]`);
      if (!el) {
        el = document.createElement('div');
        el.className = 'win';
        el.dataset.win = w.id;
        el.setAttribute('role', 'button');
        el.tabIndex = 0;
        el.innerHTML = `<div class="wbar"><i></i><i></i><i></i><span class="wt"></span></div><div class="wbody"><span></span><span></span><span></span></div>`;
        el.addEventListener('pointerdown', () => focus(w.id));
        el.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); focus(w.id); } });
        winLayer.appendChild(el);
      }
      const S = SCREENS[w.screen];
      const p = toStage(w.screen, w.x, w.y);
      el.style.left = `${p.l}%`;
      el.style.top = `${p.t}%`;
      el.style.width = `${(w.w / S.w) * S.rect.w}%`;
      el.style.height = `${(w.h / S.h) * S.rect.h}%`;
      el.style.zIndex = String(state.order.indexOf(w.id) + 1);
      el.classList.toggle('is-active', w.id === state.active);
      el.dataset.app = w.app;
      if (w.profile) el.style.setProperty('--ac', PROFILE_AV[w.profile].c);
      const label = h[w.key] as string;
      (el.querySelector('.wt') as HTMLElement).textContent = label;
      el.setAttribute('aria-label', `${h.activeLabel}: ${label}`);
      el.setAttribute('aria-pressed', String(w.id === state.active));
    });
  }

  // ── Consola / LCD ───────────────────────────────────────────
  function renderLcd() {
    const h = c();
    const L = state.last;
    const plShort = h.placementShort[state.placement];
    lcd[3].textContent = `${h.readoutState} ${plShort} · ${state.isolate ? h.isolateOn : h.isolateOff} · ${state.dual ? h.modeDual : `${h.modeSolo} (autohide-delay 1000)`} · ${state.split ? h.splitOn : h.splitOff}`.toUpperCase();
    if (!L) {
      lcd[0].textContent = h.readoutIdle;
      lcd[1].textContent = `${h.activeLabel.toUpperCase()}: ${h[byId(state.active).key]}`;
      lcd[2].innerHTML = '&nbsp;';
      return;
    }
    if (L.kind === 'open') {
      lcd[0].textContent = L.text!;
      lcd[1].innerHTML = '&nbsp;';
      lcd[2].innerHTML = '&nbsp;';
      return;
    }
    const verb = L.kind === 'move' ? `${h.readoutMove} ⌃W` : `${h.readoutSummon} ⇧`;
    lcd[0].textContent = `${verb}  ${h[L.win!.key]}  D${L.from! + 1} → D${L.to! + 1}`;
    const [rx, ry, rw, rh] = L.rel!;
    lcd[1].textContent = `rel x ${r3(rx)}  y ${r3(ry)}  w ${r3(rw)}  h ${r3(rh)}${rw === 0.35 || rh === 0.35 ? '  [min 0.35]' : ''}`;
    const [w, hh, x, y] = L.size!;
    lcd[2].textContent = `AX size ${w}×${hh} → pos ${x},${y} → size  (pt)`;
  }

  function renderStatic() {
    const h = c();
    const tags = root.querySelectorAll<HTMLElement>('[data-screen-tag]');
    tags[0].textContent = h.displayTop;
    tags[1].textContent = h.displayBottom;
    const ad = root.querySelector<HTMLElement>('[data-apple-dock]')!;
    ad.classList.toggle('is-dual', state.dual);
    ad.title = state.dual ? h.appleDock : h.appleDockHidden;
    const note = root.querySelector<HTMLElement>('[data-placement-note]');
    if (note) note.textContent = h.placementNotes[state.placement];
    root.querySelectorAll<HTMLElement>('[data-det]').forEach((d, i) => {
      d.textContent = h.placementShort[i];
      d.classList.toggle('is-on', i === state.placement);
    });
    rotary.setAttribute('aria-valuenow', String(state.placement));
    rotary.setAttribute('aria-valuetext', h.placements[state.placement]);
    rotary.style.setProperty('--rot', `${DETENTS[state.placement]}deg`);
    const hint = root.querySelector<HTMLElement>('[data-key-hint]');
    if (hint) hint.textContent = IS_MAC ? h.keyHintMac : h.keyHintOther;
  }

  function render() {
    renderWins();
    renderDock(0);
    renderDock(1);
    renderLcd();
    renderStatic();
  }

  // ── Perilla rotatoria (4 retenes) ───────────────────────────
  const DETENTS = [-135, -45, 45, 135];
  function setPlacement(i: number) {
    const v = clamp(i, 0, 3);
    if (v === state.placement) return;
    state.placement = v;
    render();
  }
  function angleToDetent(e: PointerEvent) {
    const r = rotary.getBoundingClientRect();
    const a = (Math.atan2(e.clientX - (r.left + r.width / 2), -(e.clientY - (r.top + r.height / 2))) * 180) / Math.PI;
    let best = 0;
    DETENTS.forEach((d, i) => { if (Math.abs(d - a) < Math.abs(DETENTS[best] - a)) best = i; });
    return best;
  }
  let dragging = false;
  let moved = false;
  rotary.addEventListener('pointerdown', (e) => {
    dragging = true;
    moved = false;
    rotary.classList.add('is-down');
    try { rotary.setPointerCapture(e.pointerId); } catch { /* noop */ }
  });
  rotary.addEventListener('pointermove', (e) => {
    if (!dragging) return;
    const d = angleToDetent(e);
    if (d !== state.placement) { moved = true; setPlacement(d); }
  });
  const endRotary = (e: PointerEvent) => {
    if (!dragging) return;
    dragging = false;
    rotary.classList.remove('is-down');
    if (!moved && e.type === 'pointerup') setPlacement((state.placement + 1) % 4);
  };
  rotary.addEventListener('pointerup', endRotary);
  rotary.addEventListener('pointercancel', endRotary);
  rotary.addEventListener('keydown', (e) => {
    const k = e.key;
    if (k === 'ArrowRight' || k === 'ArrowUp') setPlacement(state.placement + 1);
    else if (k === 'ArrowLeft' || k === 'ArrowDown') setPlacement(state.placement - 1);
    else if (k === 'Home') setPlacement(0);
    else if (k === 'End') setPlacement(3);
    else return;
    e.preventDefault();
  });
  root.querySelectorAll<HTMLElement>('[data-det]').forEach((d) => d.addEventListener('click', () => setPlacement(Number(d.dataset.det))));

  // ── Interruptores ───────────────────────────────────────────
  root.querySelectorAll<HTMLButtonElement>('[data-toggle]').forEach((b) => {
    b.addEventListener('click', () => {
      const k = b.dataset.toggle as 'isolate' | 'dual' | 'split';
      state[k] = !state[k];
      b.setAttribute('aria-pressed', String(state[k]));
      render();
    });
  });

  // ── Tecla ⌃W (PointerEvents en cualquier SO) ────────────────
  let keyPointer: number | null = null;
  keycap.addEventListener('pointerdown', (e) => {
    if (e.button !== 0) return;
    keyPointer = e.pointerId;
    keycap.classList.add('is-down');
    try { keycap.setPointerCapture(e.pointerId); } catch { /* noop */ }
  });
  keycap.addEventListener('pointerup', (e) => {
    if (keyPointer !== e.pointerId) return;
    keyPointer = null;
    keycap.classList.remove('is-down');
    const r = keycap.getBoundingClientRect();
    if (e.clientX >= r.left && e.clientX <= r.right && e.clientY >= r.top && e.clientY <= r.bottom) moveActive();
  });
  keycap.addEventListener('pointercancel', () => { keyPointer = null; keycap.classList.remove('is-down'); });
  keycap.addEventListener('lostpointercapture', () => { keyPointer = null; keycap.classList.remove('is-down'); });
  keycap.addEventListener('click', (e) => {
    // Activación por teclado (Enter / Espacio) — los clics de puntero ya se resolvieron en pointerup
    if ((e as MouseEvent).detail === 0) moveActive();
  });

  // ── Tecla física ⌃W: solo macOS, solo con el plano visible, nunca dentro de campos ──
  let rigVisible = false;
  new IntersectionObserver((en) => { rigVisible = en[0]?.isIntersecting ?? false; }, { threshold: 0.15 }).observe(root);
  const typing = (t: EventTarget | null) => t instanceof HTMLElement && (t.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName));
  const isCtrlW = (e: KeyboardEvent) => e.ctrlKey && !e.metaKey && !e.altKey && !e.shiftKey && (e.code === 'KeyW' || e.key.toLowerCase() === 'w');
  let physDown = false;
  if (IS_MAC) {
    window.addEventListener('keydown', (e) => {
      if (!rigVisible || typing(e.target) || document.querySelector('dialog[open]') || !isCtrlW(e)) return;
      e.preventDefault();
      if (e.repeat || physDown) return;
      physDown = true;
      keycap.classList.add('is-down');
    });
    window.addEventListener('keyup', (e) => {
      if (!physDown) return;
      if (e.code === 'KeyW' || e.key.toLowerCase() === 'w' || e.key === 'Control') {
        physDown = false;
        keycap.classList.remove('is-down');
        moveActive();
      }
    });
    window.addEventListener('blur', () => { physDown = false; keycap.classList.remove('is-down'); });
  }

  document.addEventListener('sd:locale', render);
  render();
}

export const IS_MAC: boolean = (() => {
  if (typeof navigator === 'undefined') return false;
  const uaData = (navigator as Navigator & { userAgentData?: { platform?: string } }).userAgentData;
  const mac = uaData?.platform === 'macOS' || /mac/i.test(navigator.platform || '') || /Macintosh/.test(navigator.userAgent);
  return mac && navigator.maxTouchPoints <= 1; // excluye iPad con UA de Mac
})();
