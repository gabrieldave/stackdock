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
