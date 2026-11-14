/**
 * Entrega de licencias por email vía Resend (HTTP nativo, sin SDK).
 * Best-effort: nunca lanza hacia el webhook de Stripe.
 */
import { config } from './config.js';
import { escapeHtml } from './http.js';

function planLabel(plan, locale) {
  const es = locale === 'es';
  if (plan === 'personal') return es ? 'StackDock Personal' : 'StackDock Personal';
  return es ? 'StackDock Pro' : 'StackDock Pro';
}

function licenseEmailHtml({ email, plan, licenseKey, findaroKey, locale }) {
  const es = locale === 'es';
  const safeEmail = escapeHtml(email);
  const safeLicense = escapeHtml(licenseKey);
  const safeFindaro = findaroKey ? escapeHtml(findaroKey) : '';
  const dmgUrl = `${config.publicUrl}/download/${config.dmgFileName}`;
  const title = planLabel(plan, locale);
  const intro = es
    ? 'Pago único confirmado. Guarda esta clave: la necesitarás para activar StackDock.'
    : 'One-time payment confirmed. Keep this key — you will need it to activate StackDock.';
  const downloadLabel = es ? 'Descargar StackDock (.dmg)' : 'Download StackDock (.dmg)';
  const emailLabel = es ? 'Correo' : 'Email';
  const keyLabel = es ? 'License Key' : 'License Key';
  const findaroLabel = 'Findaro Solo';
  const steps = es
    ? 'En StackDock: menú → Activar licencia → pega email + clave.'
    : 'In StackDock: menu → Activate license → paste email + key.';
  const subject = es ? `Tu licencia ${title} — BLACK EYE` : `Your ${title} license — BLACK EYE`;

  const findaroBlock = safeFindaro
    ? `<div style="font-size:12px;color:#6f6d66;margin:18px 0 8px">${findaroLabel}</div>
       <code style="display:block;word-break:break-all;color:#8a5a00;font-size:13px;background:#fff8e6;border:1px solid #FFB300;border-radius:8px;padding:12px">${safeFindaro}</code>`
    : '';

  const html = `<!DOCTYPE html>
<html lang="${es ? 'es' : 'en'}"><body style="margin:0;background:#E6E5E0;color:#111;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
<div style="max-width:560px;margin:0 auto;padding:40px 24px">
  <div style="font-size:12px;letter-spacing:0.18em;color:#6f6d66;margin-bottom:12px">BLACK EYE</div>
  <div style="height:4px;width:48px;background:#FFB300;border-radius:2px;margin-bottom:20px"></div>
  <h1 style="font-size:26px;font-weight:650;margin:0 0 10px;color:#111">${escapeHtml(title)}</h1>
  <p style="color:#3f3e39;line-height:1.55;margin:0 0 26px">${intro}</p>
  <a href="${escapeHtml(dmgUrl)}" style="display:inline-block;background:#111;color:#E6E5E0;text-decoration:none;font-weight:600;padding:14px 22px;border-radius:10px;margin-bottom:26px">${downloadLabel}</a>
  <div style="padding:18px;border:1px solid #cfcec8;border-radius:12px;background:#f4f3ef">
    <div style="font-size:12px;color:#6f6d66;margin-bottom:6px">${emailLabel}</div>
    <div style="margin-bottom:16px;word-break:break-all">${safeEmail}</div>
    <div style="font-size:12px;color:#6f6d66;margin-bottom:6px">${keyLabel}</div>
    <code style="display:block;word-break:break-all;color:#111;font-size:13px;background:#fff;border:1px solid #cfcec8;border-radius:8px;padding:12px">${safeLicense}</code>
    ${findaroBlock}
  </div>
  <p style="color:#6f6d66;font-size:12px;margin-top:26px;line-height:1.5">${steps}</p>
</div></body></html>`;

  return { subject, html };
}

/**
 * @returns {Promise<{ok: boolean, skipped?: boolean, error?: string, id?: string}>}
 */
export async function sendLicenseEmail({ email, plan = 'pro', licenseKey, findaroKey = '', locale = 'en' }) {
  if (!config.resendApiKey) {
    return { ok: false, skipped: true, error: 'RESEND_API_KEY no configurada' };
  }
  if (!email || !licenseKey) {
    return { ok: false, error: 'email o licenseKey ausente' };
  }

  const { subject, html } = licenseEmailHtml({ email, plan, licenseKey, findaroKey, locale });
  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${config.resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: `BLACK EYE <${config.resendFrom}>`,
        to: [email],
        reply_to: config.resendFrom,
        subject,
        html,
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) {
      const detail = await response.text().catch(() => '');
      console.error('[email] Resend respondió', response.status, detail.slice(0, 200));
      return { ok: false, error: `Resend HTTP ${response.status}` };
    }
    const data = await response.json().catch(() => ({}));
    return { ok: true, id: data?.id };
  } catch (error) {
    console.error('[email] fallo de red:', error.message);
    return { ok: false, error: error.message };
  }
}
