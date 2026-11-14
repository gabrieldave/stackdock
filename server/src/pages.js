/**
 * HTML propio de /pago/success, /admin y 404. Nunca interpola datos sin escapar.
 * Estética StackDock: #E6E5E0 + #FFB300, números tabulares.
 */
import { config } from './config.js';
import { escapeHtml } from './http.js';

const BASE_CSS = `
  :root { color-scheme: light; }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: #E6E5E0; color: #111;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Inter, sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  a { color: #111; }
  .wrap { max-width: 1080px; margin: 0 auto; padding: 32px 20px 64px; }
  .topbar { display: flex; align-items: center; justify-content: space-between; gap: 16px; margin-bottom: 28px; flex-wrap: wrap; }
  .brand { display: flex; align-items: center; gap: 10px; font-weight: 700; letter-spacing: .02em; }
  .dot { width: 10px; height: 10px; border-radius: 50%; background: #FFB300; box-shadow: 0 0 0 4px rgba(255,179,0,.18); }
  .muted { color: #6F6D66; }
  .card { background: #F4F3EF; border: 1px solid #CFCEC8; border-radius: 16px; padding: 22px; }
  h1 { font-size: 26px; line-height: 1.2; margin: 0 0 8px; font-weight: 650; letter-spacing: -.02em; }
  h2 { font-size: 15px; margin: 0 0 12px; font-weight: 650; letter-spacing: .01em; }
  p { line-height: 1.55; }
  code, .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
  .num { font-variant-numeric: tabular-nums; }
  .btn {
    display: inline-flex; align-items: center; justify-content: center; gap: 8px;
    background: #111; color: #E6E5E0; border: 1px solid #111; border-radius: 10px;
    padding: 10px 16px; font: inherit; font-weight: 600; cursor: pointer; text-decoration: none;
  }
  .btn:hover { background: #000; }
  .btn-ghost { background: transparent; color: #111; border-color: #CFCEC8; }
  .btn-ghost:hover { background: #E6E5E0; }
  .btn-accent { background: #FFB300; border-color: #FFB300; color: #111; }
  .btn-accent:hover { background: #FFC233; }
  .badge { display: inline-block; font-size: 11px; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; padding: 4px 8px; border-radius: 999px; background: #FFB300; color: #111; }
  .badge-soft { background: #E6E5E0; color: #3F3E39; border: 1px solid #CFCEC8; }
  .grid { display: grid; gap: 16px; }
  .row { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
  input, select {
    font: inherit; padding: 10px 12px; border-radius: 10px; border: 1px solid #CFCEC8;
    background: #fff; color: #111; min-width: 0;
  }
  input:focus, select:focus { outline: 2px solid #FFB300; outline-offset: 1px; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th { text-align: left; font-size: 11px; letter-spacing: .06em; text-transform: uppercase; color: #6F6D66; padding: 8px 10px; border-bottom: 1px solid #CFCEC8; white-space: nowrap; }
  td { padding: 10px; border-bottom: 1px solid #DDDCD6; vertical-align: top; }
  tr:last-child td { border-bottom: 0; }
  .tablewrap { overflow-x: auto; border: 1px solid #CFCEC8; border-radius: 14px; background: #F4F3EF; }
  .key {
    display: block; max-width: 320px; overflow-wrap: anywhere; font-size: 11px; color: #3F3E39;
    background: #fff; border: 1px solid #CFCEC8; border-radius: 6px; padding: 6px 8px;
  }
  .stat { font-size: 34px; font-weight: 650; letter-spacing: -.03em; line-height: 1; }
  .stat-label { font-size: 11px; letter-spacing: .06em; text-transform: uppercase; color: #6F6D66; margin-bottom: 8px; }
  .success-icon { width: 46px; height: 46px; border-radius: 50%; background: #FFB300; display: grid; place-items: center; font-size: 24px; }
  .license-box {
    margin-top: 18px; padding: 16px; border: 1px solid #CFCEC8; border-radius: 12px; background: #fff;
  }
  .license-box .key { border: 0; padding: 0; font-size: 14px; max-width: none; background: transparent; }
  .stack > * + * { margin-top: 18px; }
  ol.steps { margin: 0; padding-left: 20px; color: #3F3E39; line-height: 1.7; }
  .footer { margin-top: 36px; font-size: 12px; color: #6F6D66; }
  .toast { font-size: 12px; color: #3F3E39; min-height: 16px; }
  @media (max-width: 640px) { .wrap { padding: 20px 14px 48px; } .card { padding: 16px; } h1 { font-size: 22px; } .stat { font-size: 26px; } }
`;

function page({ title, lang = 'en', body, script = '' }) {
  return `<!DOCTYPE html>
<html lang="${lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>${escapeHtml(title)}</title>
<style>${BASE_CSS}</style>
</head>
<body>
${body}
${script ? `<script>${script}</script>` : ''}
</body>
</html>`;
}

const COPY_SCRIPT = `
document.querySelectorAll('[data-copy]').forEach(function (el) {
  el.addEventListener('click', async function () {
    var value = el.getAttribute('data-copy') || '';
    var toast = document.querySelector('[data-toast]');
    try {
      await navigator.clipboard.writeText(value);
      if (toast) toast.textContent = el.getAttribute('data-copied') || 'Copied';
    } catch (e) {
      var range = document.createRange();
      range.selectNodeContents(el);
      var sel = window.getSelection();
      if (sel) { sel.removeAllRanges(); sel.addRange(range); }
    }
  });
});
`;

export function formatUsd(cents) {
  const value = Number(cents || 0) / 100;
  return `$${value.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

export function formatDate(value) {
  if (!value) return '—';
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return `${date.toISOString().slice(0, 16).replace('T', ' ')} UTC`;
}

const PLANS = {
  personal: { en: 'Personal', es: 'Personal', macs: 1 },
  pro: { en: 'Pro', es: 'Pro', macs: 3 },
  findaro: { en: 'Findaro Solo', es: 'Findaro Solo', macs: 1 },
};

export function planLabel(plan, locale = 'en') {
  const entry = PLANS[plan] || PLANS.pro;
  return `StackDock ${entry[locale === 'es' ? 'es' : 'en']}`;
}

export function renderSuccessPage({ order, locale = 'en', sessionId = '' }) {
  const es = locale === 'es';
  const safeSession = escapeHtml(sessionId);
  const downloadHref = `/download/${config.dmgFileName}`;
  const support = config.resendFrom;

  let content;
  if (order && order.license_key) {
    const email = escapeHtml(order.email || '');
    const license = escapeHtml(order.license_key);
    const findaro = order.findaro_key ? escapeHtml(order.findaro_key) : '';
    const plan = escapeHtml(planLabel(order.plan, locale));
    const amount = escapeHtml(formatUsd(order.amount_cents));
    const findaroBlock = findaro
      ? `<div class="license-box">
           <div class="stat-label">Findaro Solo</div>
           <code class="key" data-copy="${findaro}" data-copied="${es ? 'Copiada' : 'Copied'}">${findaro}</code>
         </div>`
      : '';
    content = `
      <div class="card stack">
        <div class="row">
          <div class="success-icon" aria-hidden="true">✓</div>
          <div>
            <h1>${es ? 'Pago confirmado' : 'Payment confirmed'}</h1>
            <p class="muted" style="margin:0">${plan} · <span class="num">${amount}</span> USD</p>
          </div>
        </div>
        <p style="margin:0">${es
          ? 'Tu licencia ya está lista. Cópiala y actívala en StackDock; también te la enviamos por email.'
          : 'Your license is ready. Copy it and activate StackDock — we also emailed it to you.'}</p>
        <div class="license-box">
          <div class="stat-label">${es ? 'Correo' : 'Email'}</div>
          <div style="overflow-wrap:anywhere;margin-bottom:14px">${email}</div>
          <div class="stat-label">License Key</div>
          <code class="key" data-copy="${license}" data-copied="${es ? 'Copiada' : 'Copied'}">${license}</code>
          <div class="row" style="margin-top:14px">
            <button type="button" class="btn btn-accent" data-copy="${license}" data-copied="${es ? 'Copiada' : 'Copied'}">${es ? 'Copiar licencia' : 'Copy license'}</button>
            <a class="btn btn-ghost" href="${escapeHtml(downloadHref)}" download>${es ? 'Descargar .dmg' : 'Download .dmg'}</a>
          </div>
          <div class="toast" data-toast role="status" aria-live="polite"></div>
        </div>
        ${findaroBlock}
        <div>
          <h2>${es ? 'Cómo activar' : 'How to activate'}</h2>
          <ol class="steps">
            <li>${es ? 'Abre StackDock y ve al menú de la app.' : 'Open StackDock and go to the app menu.'}</li>
            <li>${es ? 'Elige «Activar licencia».' : 'Choose “Activate license”.'}</li>
            <li>${es ? 'Pega tu correo y la clave. Listo.' : 'Paste your email and key. Done.'}</li>
          </ol>
        </div>
      </div>`;
  } else if (order) {
    content = `
      <div class="card stack">
        <div class="row">
          <div class="success-icon" aria-hidden="true">…</div>
          <div><h1>${es ? 'Estamos preparando tu licencia' : 'Preparing your license'}</h1></div>
        </div>
        <p>${es
          ? 'El pago se registró y la licencia se está generando. Recarga esta página en unos segundos.'
          : 'The payment was recorded and your license is being generated. Reload this page in a few seconds.'}</p>
        <p class="muted" style="font-size:12px;overflow-wrap:anywhere">session_id: ${safeSession}</p>
        <div class="row"><button type="button" class="btn" onclick="location.reload()">${es ? 'Recargar' : 'Reload'}</button>
        <a class="btn btn-ghost" href="mailto:${escapeHtml(support)}">${escapeHtml(support)}</a></div>
      </div>`;
  } else {
    content = `
      <div class="card stack">
        <h1>${es ? 'Busca tu licencia' : 'Find your license'}</h1>
        <p>${es
          ? 'No encontramos una orden para este enlace. Tu licencia se envía al email de compra. Si no la recibes en unos minutos, escríbenos indicando el email usado en el pago.'
          : 'We could not find an order for this link. Your license is sent to the purchase email. If it does not arrive within a few minutes, contact us with the email used at checkout.'}</p>
        ${safeSession ? `<p class="muted" style="font-size:12px;overflow-wrap:anywhere">session_id: ${safeSession}</p>` : ''}
        <div class="row">
          <a class="btn" href="mailto:${escapeHtml(support)}?subject=StackDock%20license">${es ? 'Escribir a soporte' : 'Contact support'}</a>
          <a class="btn btn-ghost" href="/">${es ? 'Volver al inicio' : 'Back to home'}</a>
        </div>
      </div>`;
  }

  return page({
    title: es ? 'StackDock · Tu licencia' : 'StackDock · Your license',
    lang: es ? 'es' : 'en',
    body: `<div class="wrap">
      <header class="topbar">
        <div class="brand"><span class="dot"></span>BLACK EYE · StackDock</div>
        <a class="muted" style="text-decoration:none;font-size:13px" href="/">stackdock.iareal.net</a>
      </header>
      ${content}
      <p class="footer">${es ? '¿Problemas? Escríbenos a' : 'Need help?'} <a href="mailto:${escapeHtml(support)}">${escapeHtml(support)}</a>.</p>
    </div>`,
    script: COPY_SCRIPT,
  });
}

function orderRows(orders, locale) {
  if (!orders.length) {
    return `<tr><td colspan="7" class="muted">${locale === 'es' ? 'Sin órdenes todavía.' : 'No orders yet.'}</td></tr>`;
  }
  return orders
    .map((order) => {
      const hasKey = Boolean(order.license_key);
      const keyHtml = hasKey
        ? `<code class="key" data-copy="${escapeHtml(order.license_key)}" title="${escapeHtml(order.license_key)}">${escapeHtml(order.license_key)}</code>`
        : '<span class="muted">—</span>';
      const resend = hasKey
        ? `<button type="button" class="btn btn-ghost" style="padding:6px 10px;font-size:12px" data-resend="${Number(order.id)}">${locale === 'es' ? 'Reenviar' : 'Resend'}</button>`
        : `<button type="button" class="btn btn-ghost" style="padding:6px 10px;font-size:12px" data-resend="${Number(order.id)}">${locale === 'es' ? 'Emitir y enviar' : 'Issue & send'}</button>`;
      return `<tr>
        <td class="num muted" style="white-space:nowrap">${escapeHtml(formatDate(order.created_at))}</td>
        <td style="overflow-wrap:anywhere">${escapeHtml(order.email || '—')}</td>
        <td>${escapeHtml(order.plan || '—')}${order.add_findaro ? ' <span class="badge">+ Findaro</span>' : ''}</td>
        <td class="num" style="white-space:nowrap">${escapeHtml(formatUsd(order.amount_cents))} <span class="muted">${escapeHtml(order.currency || 'usd')}</span></td>
        <td><span class="badge badge-soft">${escapeHtml(order.status || '—')}</span></td>
        <td>${keyHtml}</td>
        <td>${resend}</td>
      </tr>`;
    })
    .join('');
}

function leadRows(leads, locale) {
  if (!leads.length) {
    return `<tr><td colspan="6" class="muted">${locale === 'es' ? 'Sin leads todavía.' : 'No leads yet.'}</td></tr>`;
  }
  return leads
    .map(
      (lead) => `<tr>
        <td class="num muted" style="white-space:nowrap">${escapeHtml(formatDate(lead.created_at))}</td>
        <td style="overflow-wrap:anywhere">${escapeHtml(lead.email || '—')}</td>
        <td>${escapeHtml(lead.locale || '—')}</td>
        <td>${escapeHtml(lead.version || '—')}</td>
        <td class="muted">${escapeHtml(lead.source || '—')}</td>
        <td>${escapeHtml(lead.ip_country || '—')}</td>
      </tr>`,
    )
    .join('');
}

const ADMIN_SCRIPT = `
(function () {
  var toast = document.querySelector('[data-toast]');
  var setToast = function (msg) { if (toast) toast.textContent = msg; };

  document.querySelectorAll('[data-copy]').forEach(function (el) {
    el.addEventListener('click', async function () {
      try { await navigator.clipboard.writeText(el.getAttribute('data-copy') || ''); setToast('Copied'); }
      catch (e) { setToast('Copy failed'); }
    });
  });

  document.querySelectorAll('[data-resend]').forEach(function (btn) {
    btn.addEventListener('click', async function () {
      var original = btn.textContent;
      btn.disabled = true;
      btn.textContent = '…';
      try {
        var response = await fetch('/api/admin/resend-license', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
          body: JSON.stringify({ orderId: Number(btn.getAttribute('data-resend')) })
        });
        var data = await response.json().catch(function () { return {}; });
        if (!response.ok) throw new Error(data.error || ('HTTP ' + response.status));
        btn.textContent = '✓';
        setToast('Email sent to ' + data.email);
      } catch (error) {
        btn.textContent = '✕';
        setToast(error.message);
      } finally {
        setTimeout(function () { btn.disabled = false; btn.textContent = original; }, 1800);
      }
    });
  });

  var form = document.querySelector('[data-issue-form]');
  if (form) form.addEventListener('submit', async function (event) {
    event.preventDefault();
    var out = document.querySelector('[data-issue-out]');
    var submit = form.querySelector('button[type="submit"]');
    if (out) out.textContent = '…';
    if (submit) submit.disabled = true;
    try {
      var email = form.querySelector('input[name="email"]').value.trim();
      var plan = form.querySelector('select[name="plan"]').value;
      var response = await fetch('/api/admin/issue-license', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ email: email, plan: plan })
      });
      var data = await response.json().catch(function () { return {}; });
      if (!response.ok) throw new Error(data.error || ('HTTP ' + response.status));
      if (out) {
        out.textContent = '';
        var code = document.createElement('code');
        code.className = 'key';
        code.setAttribute('data-copy', data.licenseKey);
        code.textContent = data.licenseKey;
        code.title = 'Click to copy';
        code.addEventListener('click', function () {
          navigator.clipboard.writeText(data.licenseKey).then(function () { setToast('Copied'); });
        });
        out.appendChild(code);
      }
      setToast('License issued for ' + data.email);
    } catch (error) {
      if (out) out.textContent = error.message;
      setToast(error.message);
    } finally {
      if (submit) submit.disabled = false;
    }
  });

  var logout = document.querySelector('[data-logout]');
  if (logout) logout.addEventListener('click', async function () {
    await fetch('/api/admin/logout', { method: 'POST', headers: { Accept: 'application/json' } }).catch(function () {});
    location.assign('/');
  });
})();
`;

export function renderAdminPage({ email, orders = [], leads = [], totals = {}, logs = [], locale = 'en' }) {
  const es = locale === 'es';
  const safeEmail = escapeHtml(email);
  const revenue = formatUsd(totals.revenue_cents || 0);
  const orderCount = Number(totals.orders || 0);
  const orders30 = Number(totals.orders_30d || 0);
  const logRows = logs.length
    ? logs.map(
        (log) => `<tr><td class="num muted" style="white-space:nowrap">${escapeHtml(formatDate(log.created_at))}</td>
          <td style="overflow-wrap:anywhere">${escapeHtml(log.email || '—')}</td>
          <td>${escapeHtml(log.plan || '—')}</td>
          <td>${escapeHtml(log.action || '—')}</td></tr>`,
      ).join('')
    : `<tr><td colspan="4" class="muted">${es ? 'Sin actividad.' : 'No activity yet.'}</td></tr>`;

  return page({
    title: 'StackDock · Admin',
    lang: locale,
    body: `<div class="wrap">
      <header class="topbar">
        <div class="brand"><span class="dot"></span>BLACK EYE · StackDock Admin</div>
        <div class="row">
          <span class="muted" style="font-size:13px">${safeEmail}</span>
          <button type="button" class="btn btn-ghost" data-logout>${es ? 'Salir' : 'Sign out'}</button>
        </div>
      </header>

      <div class="grid" style="grid-template-columns:repeat(auto-fit,minmax(190px,1fr));margin-bottom:22px">
        <div class="card"><div class="stat-label">${es ? 'Ingresos totales' : 'Total revenue'}</div><div class="stat num">${escapeHtml(revenue)}</div><div class="muted" style="font-size:12px;margin-top:6px">USD</div></div>
        <div class="card"><div class="stat-label">${es ? 'Órdenes' : 'Orders'}</div><div class="stat num">${orderCount}</div><div class="muted" style="font-size:12px;margin-top:6px">${orders30} ${es ? 'en 30 días' : 'in 30 days'}</div></div>
        <div class="card"><div class="stat-label">${es ? 'Leads de trial' : 'Trial leads'}</div><div class="stat num">${Number(leads.length)}</div><div class="muted" style="font-size:12px;margin-top:6px">${es ? 'últimos 100' : 'latest 100'}</div></div>
      </div>

      <div class="card" style="margin-bottom:22px">
        <h2>${es ? 'Emitir licencia manual' : 'Issue manual license'}</h2>
        <form class="row" data-issue-form autocomplete="off">
          <input type="email" name="email" placeholder="customer@email.com" required style="flex:1 1 240px">
          <select name="plan">
            <option value="personal">Personal · $9.99</option>
            <option value="pro" selected>Pro · $19.00</option>
          </select>
          <button type="submit" class="btn btn-accent">${es ? 'Emitir' : 'Issue'}</button>
        </form>
        <div data-issue-out style="margin-top:12px"></div>
      </div>

      <h2 style="margin:0 0 10px">${es ? 'Órdenes' : 'Orders'}</h2>
      <div class="tablewrap" style="margin-bottom:22px">
        <table>
          <thead><tr><th>${es ? 'Fecha' : 'Date'}</th><th>Email</th><th>Plan</th><th>${es ? 'Importe' : 'Amount'}</th><th>${es ? 'Estado' : 'Status'}</th><th>License</th><th></th></tr></thead>
          <tbody>${orderRows(orders, locale)}</tbody>
        </table>
      </div>

      <h2 style="margin:0 0 10px">${es ? 'Leads del trial' : 'Trial leads'}</h2>
      <div class="tablewrap" style="margin-bottom:22px">
        <table>
          <thead><tr><th>${es ? 'Fecha' : 'Date'}</th><th>Email</th><th>Locale</th><th>${es ? 'Versión' : 'Version'}</th><th>Source</th><th>${es ? 'País' : 'Country'}</th></tr></thead>
          <tbody>${leadRows(leads, locale)}</tbody>
        </table>
      </div>

      <h2 style="margin:0 0 10px">${es ? 'Actividad de licencias' : 'License activity'}</h2>
      <div class="tablewrap">
        <table>
          <thead><tr><th>${es ? 'Fecha' : 'Date'}</th><th>Email</th><th>Plan</th><th>${es ? 'Acción' : 'Action'}</th></tr></thead>
          <tbody>${logRows}</tbody>
        </table>
      </div>
      <div class="toast" data-toast role="status" aria-live="polite" style="margin-top:14px"></div>
      <p class="footer">${es ? 'Sesión de 8 h · acceso restringido en servidor.' : '8-hour session · access enforced server-side.'}</p>
    </div>`,
    script: ADMIN_SCRIPT,
  });
}

export function renderNotFoundPage(locale = 'en') {
  const es = locale === 'es';
  return page({
    title: es ? 'StackDock · Página no encontrada' : 'StackDock · Page not found',
    lang: es ? 'es' : 'en',
    body: `<div class="wrap">
      <header class="topbar"><div class="brand"><span class="dot"></span>BLACK EYE · StackDock</div></header>
      <div class="card stack">
        <h1>404</h1>
        <p>${es ? 'Esta página no existe.' : 'This page does not exist.'}</p>
        <div class="row"><a class="btn" href="/">${es ? 'Ir al inicio' : 'Go home'}</a></div>
      </div>
    </div>`,
  });
}
