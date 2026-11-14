/** Descarga (trial 14 días), checkout POST /api/checkout, legales y copiado de SHA-256. */
import { copy, funnel, isPending, usd, type Locale } from './config/funnel';
import { currentLocale, isPreview } from './i18n';

let rememberedEmail: string | undefined;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const m = () => copy[currentLocale()].modal;

function dialog(name: string) {
  return document.querySelector<HTMLDialogElement>(`dialog[data-modal="${name}"]`)!;
}
function open(d: HTMLDialogElement) {
  if (!d.open) d.showModal();
}

export interface CheckoutPayload {
  plan: 'personal' | 'pro';
  addFindaro: boolean;
  locale: Locale;
  customerEmail?: string;
}

export function initCommerce() {
  // Cerrar modales (botón ✕ o clic en el fondo)
  document.querySelectorAll<HTMLDialogElement>('dialog.modal').forEach((d) => {
    d.addEventListener('click', (e) => { if (e.target === d) d.close(); });
    d.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', () => d.close()));
  });

  // ── Descarga ───────────────────────────────────────────────
  const dl = dialog('download');
  const form = dl.querySelector<HTMLFormElement>('[data-dl-form]')!;
  const email = form.querySelector<HTMLInputElement>('input[name="email"]')!;
  const err = form.querySelector<HTMLElement>('[data-err]')!;
  const demo = form.querySelector<HTMLElement>('[data-dl-demo]')!;
  document.querySelectorAll('[data-open-download]').forEach((b) =>
    b.addEventListener('click', () => {
      err.hidden = true;
      demo.hidden = true;
      open(dl);
      setTimeout(() => email.focus(), 40);
    }),
  );

  const startDownload = () => {
    const a = document.createElement('a');
    a.href = funnel.dmgUrl;
    a.download = funnel.dmgFileName;
    document.body.appendChild(a);
    a.click();
    a.remove();
  };

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const v = email.value.trim();
    if (v && !EMAIL_RE.test(v)) {
      err.hidden = false;
      email.setAttribute('aria-invalid', 'true');
      email.focus();
      return;
    }
    err.hidden = true;
    email.removeAttribute('aria-invalid');
    if (v) {
      rememberedEmail = v;
      if (isPending(funnel.trialWebhookUrl) || isPreview()) demo.hidden = false;
      else {
        fetch(funnel.trialWebhookUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email: v, locale: currentLocale(), version: funnel.version, trialDays: funnel.trialDays, source: 'stackdock-web' }),
          keepalive: true,
        }).catch(() => { /* la descarga no depende del webhook */ });
      }
    }
    startDownload();
  });
  form.querySelector('[data-dl-skip]')!.addEventListener('click', startDownload);

  // ── Checkout ───────────────────────────────────────────────
  const co = dialog('checkout');
  const coTitle = co.querySelector<HTMLElement>('[data-co-title]')!;
  const coBody = co.querySelector<HTMLElement>('[data-co-body]')!;
  const bump = document.querySelector<HTMLInputElement>('[data-bump]');
  const total = document.querySelector<HTMLElement>('[data-total]');

  const updateTotal = () => {
    if (!total) return;
    const base = Number(total.dataset.base);
    const add = bump?.checked ? Number(total.dataset.bumpPrice) : 0;
    total.textContent = usd(+(base + add).toFixed(2));
  };
  bump?.addEventListener('change', updateTotal);

  async function checkout(plan: 'personal' | 'pro', btn: HTMLButtonElement) {
    const payload: CheckoutPayload = {
      plan,
      addFindaro: plan === 'pro' && !!bump?.checked,
      locale: currentLocale(),
      ...(rememberedEmail ? { customerEmail: rememberedEmail } : {}),
    };
    if (isPreview()) {
      coTitle.textContent = m().coDemoTitle;
      coBody.innerHTML = `<p>${m().coDemoBody}</p><pre class="payload mono">${JSON.stringify(payload, null, 2)}</pre>`;
      open(co);
      return;
    }
    coTitle.textContent = m().coLoading;
    coBody.innerHTML = '<div class="loader" aria-hidden="true"><span></span><span></span><span></span></div>';
    open(co);
    btn.disabled = true;
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 15000);
    try {
      const res = await fetch(funnel.checkoutEndpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify(payload),
        signal: ctrl.signal,
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = (await res.json()) as { url?: string };
      const url = data.url ? new URL(data.url, location.href) : null;
      if (!url || url.protocol !== 'https:') throw new Error('invalid url');
      location.assign(url.toString());
    } catch {
      coTitle.textContent = 'Checkout';
      coBody.innerHTML = `<p class="co-err">${m().coError}</p><div class="dl-actions"><button type="button" class="btn btn-key" data-retry>${m().retry}</button><a class="btn btn-text" href="mailto:${funnel.supportEmail}?subject=StackDock%20${plan}">${funnel.supportEmail}</a></div>`;
      coBody.querySelector('[data-retry]')!.addEventListener('click', () => checkout(plan, btn));
    } finally {
      clearTimeout(timer);
      btn.disabled = false;
    }
  }
  document.querySelectorAll<HTMLButtonElement>('[data-checkout]').forEach((b) =>
    b.addEventListener('click', () => checkout(b.dataset.checkout as 'personal' | 'pro', b)),
  );

  // ── Legales ────────────────────────────────────────────────
  const lg = dialog('legal');
  document.querySelectorAll<HTMLButtonElement>('[data-legal]').forEach((b) =>
    b.addEventListener('click', () => {
      const k = b.dataset.legal as 'terms' | 'privacy' | 'refund';
      const pack = copy[currentLocale()].legal[k];
      lg.querySelector<HTMLElement>('[data-legal-title]')!.textContent = pack.title;
      lg.querySelector<HTMLElement>('[data-legal-body]')!.innerHTML = pack.body;
      open(lg);
    }),
  );

  // ── Copiar SHA-256 ─────────────────────────────────────────
  document.querySelectorAll<HTMLElement>('[data-copy]').forEach((el) => {
    const doCopy = async () => {
      try {
        await navigator.clipboard.writeText(el.dataset.copy!);
      } catch {
        const r = document.createRange();
        r.selectNodeContents(el);
        const s = getSelection();
        s?.removeAllRanges();
        s?.addRange(r);
      }
      el.dataset.state = 'copied';
      el.setAttribute('data-tip', m().copied);
      setTimeout(() => { delete el.dataset.state; }, 1400);
    };
    el.addEventListener('click', doCopy);
    el.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); doCopy(); } });
  });
}
