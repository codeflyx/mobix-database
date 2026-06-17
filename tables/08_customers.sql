-- ============================================================
-- TABLE: customers
-- Purpose: Customer contact list and credit configuration.
-- credit_limit: max PKR balance allowed on khata/udhaar.
--   0 = credit not allowed for this customer.
-- Outstanding balance is derived (not stored):
--   SUM(total - paid_total) FROM invoices
--   WHERE customer_id=? AND status != 'cancelled' AND deleted_at IS NULL
-- deleted_at: soft delete — keep for historical invoice display.
-- ============================================================

CREATE TABLE IF NOT EXISTS customers (
  id              TEXT PRIMARY KEY NOT NULL,
  owner_user_id   TEXT NOT NULL REFERENCES users (id),

  name            TEXT NOT NULL,
  phone           TEXT,
  alternate_phone TEXT,
  cnic            TEXT,
  address         TEXT,

  -- money: PKR whole rupees
  credit_limit    INTEGER NOT NULL DEFAULT 0,

  notes           TEXT,

  deleted_at      TEXT,  -- soft delete; NULL = active

  created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS customers_owner_phone_idx
  ON customers (owner_user_id, phone);
