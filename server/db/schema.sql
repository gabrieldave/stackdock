-- StackDock · esquema idempotente (PostgreSQL 17)
-- Ejecutado al arrancar desde server/src/db.js. Nunca borra datos.

CREATE TABLE IF NOT EXISTS orders (
  id                serial PRIMARY KEY,
  created_at        timestamptz NOT NULL DEFAULT now(),
  email             text,
  plan              text,
  add_findaro       boolean NOT NULL DEFAULT false,
  amount_cents      integer,
  currency          text NOT NULL DEFAULT 'usd',
  stripe_session_id text,
  stripe_event_id   text,
  status            text,
  license_key       text,
  findaro_key       text,
  locale            text,
  raw               jsonb
);

CREATE UNIQUE INDEX IF NOT EXISTS orders_stripe_session_id_key ON orders (stripe_session_id);
CREATE UNIQUE INDEX IF NOT EXISTS orders_stripe_event_id_key ON orders (stripe_event_id);
CREATE INDEX IF NOT EXISTS orders_created_at_idx ON orders (created_at DESC);
CREATE INDEX IF NOT EXISTS orders_email_idx ON orders (email);

CREATE TABLE IF NOT EXISTS trial_leads (
  id          serial PRIMARY KEY,
  created_at  timestamptz NOT NULL DEFAULT now(),
  email       text NOT NULL UNIQUE,
  locale      text,
  version     text,
  trial_days  integer NOT NULL DEFAULT 14,
  source      text,
  ip_country  text
);

CREATE INDEX IF NOT EXISTS trial_leads_created_at_idx ON trial_leads (created_at DESC);

CREATE TABLE IF NOT EXISTS license_logs (
  id          serial PRIMARY KEY,
  created_at  timestamptz NOT NULL DEFAULT now(),
  email       text,
  plan        text,
  order_id    integer,
  action      text
);

CREATE INDEX IF NOT EXISTS license_logs_email_idx ON license_logs (email);
CREATE INDEX IF NOT EXISTS license_logs_created_at_idx ON license_logs (created_at DESC);

CREATE TABLE IF NOT EXISTS admin_sessions (
  token       text PRIMARY KEY,
  email       text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL
);

CREATE INDEX IF NOT EXISTS admin_sessions_expires_at_idx ON admin_sessions (expires_at);

-- ── Capa 5/6: licencias cifradas en reposo + control de asientos ──
ALTER TABLE orders ADD COLUMN IF NOT EXISTS license_key_enc text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS license_key_hash text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS findaro_key_enc text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS stripe_payment_intent text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS revoked_at timestamptz;

CREATE INDEX IF NOT EXISTS orders_license_key_hash_idx ON orders (license_key_hash);
CREATE INDEX IF NOT EXISTS orders_stripe_payment_intent_idx ON orders (stripe_payment_intent);

CREATE TABLE IF NOT EXISTS hardware_trials (
  device_id      text PRIMARY KEY,
  first_seen_at  timestamptz NOT NULL DEFAULT now(),
  last_seen_at   timestamptz NOT NULL DEFAULT now(),
  app_version    text,
  ip_country     text
);

CREATE TABLE IF NOT EXISTS license_activations (
  id             serial PRIMARY KEY,
  license_hash   text NOT NULL,
  order_id       integer REFERENCES orders(id) ON DELETE CASCADE,
  email          text NOT NULL,
  plan           text NOT NULL,
  device_id      text NOT NULL,
  app_version    text,
  first_seen_at  timestamptz NOT NULL DEFAULT now(),
  last_seen_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (license_hash, device_id)
);

CREATE INDEX IF NOT EXISTS license_activations_hash_idx ON license_activations (license_hash);
CREATE INDEX IF NOT EXISTS license_activations_email_idx ON license_activations (email);
