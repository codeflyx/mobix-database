-- ============================================================
-- TABLE: suppliers
-- Purpose: Supplier contact list.
-- company_name: optional trading/business name separate from
--   the contact person name.
-- Outstanding dues are derived:
--   SUM(total - paid_total) FROM purchases
--   WHERE supplier_id=? AND status != 'cancelled' AND deleted_at IS NULL
-- deleted_at: soft delete.
-- ============================================================

CREATE TABLE IF NOT EXISTS suppliers (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),

  name          TEXT NOT NULL,
  phone         TEXT,
  cnic          TEXT,
  address       TEXT,
  company_name  TEXT,

  notes         TEXT,

  deleted_at    TEXT,  -- soft delete

  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
