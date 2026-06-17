-- ============================================================
-- TABLE: stock_movements
-- Purpose: Ledger of every quantity change for non-serialized
--   (qty-type) products. Stock on hand = SUM(qty_delta).
-- qty_delta: positive = stock in, negative = stock out/return.
-- reason values:
--   'purchase'        → stock arrived via a purchase
--   'purchase_return' → stock sent back to supplier
--   'sale'            → units sold via invoice
--   'sale_return'     → units returned by customer
--   'adjustment'      → manual stock correction
-- ref_table / ref_id: the source document that caused the movement.
-- ============================================================

CREATE TABLE IF NOT EXISTS stock_movements (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),
  product_id    TEXT NOT NULL REFERENCES products (id),

  qty_delta     INTEGER NOT NULL,
  unit_cost     INTEGER NOT NULL DEFAULT 0,

  reason        TEXT NOT NULL DEFAULT 'purchase'
                CHECK (reason IN ('purchase', 'purchase_return', 'sale', 'sale_return', 'adjustment')),

  ref_table     TEXT,
  ref_id        TEXT,
  notes         TEXT,

  created_by    TEXT REFERENCES users (id),
  occurred_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS stock_movements_product_idx
  ON stock_movements (owner_user_id, product_id);
