-- ============================================================
-- TABLE: product_stock
-- Purpose: Current stock quantity for 'quantity'-type products.
-- IMEI products do NOT use this table — their stock level is
--   COUNT(*) FROM imei_units WHERE product_id=? AND status='in_stock'.
-- One row per product (enforced by unique index).
-- quantity is updated on every purchase/sale/adjustment.
-- ============================================================

CREATE TABLE IF NOT EXISTS product_stock (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),
  product_id    TEXT NOT NULL REFERENCES products (id),

  quantity      INTEGER NOT NULL DEFAULT 0,

  updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS product_stock_product_uq
  ON product_stock (product_id);
