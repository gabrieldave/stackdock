/**
 * Configuración por entorno. Nunca imprime valores secretos.
 * Todas las variables son opcionales excepto DATABASE_URL para las rutas que usan BD.
 */

const DEFAULT_PAYMENT_WEBHOOK = 'https://n8n.vibesystems.tech/webhook/payment';
const DEFAULT_TRIAL_WEBHOOK = 'https://n8n.vibesystems.tech/webhook/stackdock-trial';
const DEFAULT_GOOGLE_CLIENT_ID =
  '1091222021847-ph8k6rbvkpkk9gf1j41v6hiiqje6vnlc.apps.googleusercontent.com';

function str(name, fallback = '') {
  const value = process.env[name];
  if (value === undefined || value === null) return fallback;
  const trimmed = String(value).trim();
  return trimmed === '' ? fallback : trimmed;
}

function int(name, fallback) {
  const value = Number.parseInt(str(name, ''), 10);
  return Number.isFinite(value) ? value : fallback;
}

export const config = {
  env: str('NODE_ENV', 'production'),
  port: int('PORT', 8080),
  version: '4.0.6',

  publicDir: str('PUBLIC_DIR', '/app/public'),
  storageDir: str('STORAGE_DIR', '/app/storage'),

  databaseUrl: str('DATABASE_URL', ''),
  databaseSsl: str('DATABASE_SSL', 'auto').toLowerCase(),
  // SSL de PostgreSQL: se calcula en db.js. Un valor truthy aquí solo indica "forzar".

  paymentWebhookUrl: str('N8N_PAYMENT_WEBHOOK', DEFAULT_PAYMENT_WEBHOOK),
  trialWebhookUrl: str('N8N_TRIAL_WEBHOOK', DEFAULT_TRIAL_WEBHOOK),

  resendApiKey: str('RESEND_API_KEY', ''),
  resendFrom: str('RESEND_FROM', 'stackdock@iareal.net'),

  licensePrivateKey: str('LICENSE_PRIVATE_KEY', ''),
  stripeWebhookSecret: str('STRIPE_WEBHOOK_SECRET', ''),

  googleClientId: str('GOOGLE_CLIENT_ID', DEFAULT_GOOGLE_CLIENT_ID),
  googleClientSecret: str('GOOGLE_CLIENT_SECRET', ''),

  adminAllowedEmails: str('ADMIN_ALLOWED_EMAILS', 'david.del.rio.colin@gmail.com')
    .split(',')
    .map((email) => email.trim().toLowerCase())
    .filter(Boolean),

  publicUrl: str('PUBLIC_URL', 'https://stackdock.iareal.net').replace(/\/+$/, ''),
  sessionSecret: str('SESSION_SECRET', ''),

  dmgFileName: 'StackDock-4.0.6.dmg',
  sessionHours: 8,
  jsonLimitBytes: 64 * 1024,
  trialRateLimit: { max: 10, windowMs: 60 * 60 * 1000 },
};

/** Resumen sin secretos, seguro para logs de arranque. */
export function describeConfig() {
  return {
    env: config.env,
    port: config.port,
    publicDir: config.publicDir,
    storageDir: config.storageDir,
    database: config.databaseUrl ? 'configured' : 'missing',
    databaseSsl: config.databaseSsl,
    paymentWebhook: config.paymentWebhookUrl ? 'configured' : 'missing',
    trialWebhook: config.trialWebhookUrl ? 'configured' : 'missing',
    resend: config.resendApiKey ? 'configured' : 'missing',
    licenseKey: config.licensePrivateKey ? 'configured' : 'missing',
    stripeWebhookSecret: config.stripeWebhookSecret ? 'configured' : 'missing',
    googleOauth: config.googleClientSecret ? 'configured' : 'missing',
    publicUrl: config.publicUrl,
    sessionSecret: config.sessionSecret ? 'configured' : 'missing',
  };
}
