-- ============================================================
-- TABLE: purchase_items
-- Purpose: Line items for each purchase order.
-- imei_unit_id: set for IMEI-type products — links to the
--   exact imei_units row created by this line item.
--   NULL for quantity-type products.
-- line_total = qty * unit_cost (after any item-level discount).
-- ============================================================

CREATE TABLE IF NOT EXISTS purchase_items (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),

  purchase_id   TEXT NOT NULL REFERENCES purchases (id),
  product_id    TEXT NOT NULL REFERENCES products (id),
  imei_unit_id  TEXT REFERENCES imei_units (id),

  qty           INTEGER NOT NULL DEFAULT 1,

  -- money: PKR whole rupees
  unit_cost     INTEGER NOT NULL DEFAULT 0,
  line_total    INTEGER NOT NULL DEFAULT 0,

  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS purchase_items_purchase_idx
  ON purchase_items (purchase_id);
