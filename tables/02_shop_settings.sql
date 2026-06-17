-- ============================================================
-- TABLE: shop_settings
-- Purpose: Shop identity and invoice configuration.
-- One row per shop (V1 single-tenant).
-- Kept separate from users so deleting a user never breaks
-- historical invoice headers that snapshot shop info.
-- ============================================================

CREATE TABLE IF NOT EXISTS shop_settings (
  id                   TEXT PRIMARY KEY NOT NULL,
  owner_user_id        TEXT NOT NULL REFERENCES users (id),

  shop_name            TEXT NOT NULL,
  owner_name           TEXT NOT NULL,

  phone                TEXT,
  email                TEXT,
  address              TEXT,

  logo_path            TEXT,
  currency_code        TEXT NOT NULL DEFAULT 'PKR',

  invoice_prefix       TEXT NOT NULL DEFAULT 'INV',   -- e.g. INV-000001
  purchase_prefix      TEXT NOT NULL DEFAULT 'PUR',   -- e.g. PUR-000001

  receipt_footer_text  TEXT,

  created_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
