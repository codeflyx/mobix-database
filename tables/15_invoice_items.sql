-- ============================================================
-- TABLE: invoice_items
-- Purpose: Line items for each invoice (sale or return).
-- imei_unit_id: set for IMEI-type products — links to the
--   exact imei_units row that was sold. NULL for quantity products.
-- unit_cost_at_sale: snapshot of purchase cost at time of sale.
--   NEVER update after insert. Used for profit calculation:
--   profit = line_total - (unit_cost_at_sale * qty)
-- warranty_expiry_date: computed by app at insert time:
--   occurred_at + warranty_days. NULL if warranty_days = 0.
-- line_total = (unit_price - discount) * qty
-- ============================================================

CREATE TABLE IF NOT EXISTS invoice_items (
  id                   TEXT PRIMARY KEY NOT NULL,
  owner_user_id        TEXT NOT NULL REFERENCES users (id),

  invoice_id           TEXT NOT NULL REFERENCES invoices (id),
  product_id           TEXT NOT NULL REFERENCES products (id),
  imei_unit_id         TEXT REFERENCES imei_units (id),

  qty                  INTEGER NOT NULL DEFAULT 1,

  -- money: PKR whole rupees
  unit_price           INTEGER NOT NULL DEFAULT 0,
  discount             INTEGER NOT NULL DEFAULT 0,
  line_total           INTEGER NOT NULL DEFAULT 0,

  unit_cost_at_sale    INTEGER NOT NULL DEFAULT 0,
  warranty_days        INTEGER NOT NULL DEFAULT 0,
  warranty_expiry_date TEXT,

  created_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS invoice_items_invoice_idx
  ON invoice_items (invoice_id);

CREATE INDEX IF NOT EXISTS invoice_items_warranty_idx
  ON invoice_items (warranty_expiry_date)
  WHERE warranty_expiry_date IS NOT NULL;
