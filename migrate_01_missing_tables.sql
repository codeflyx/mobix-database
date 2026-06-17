-- ============================================================
-- MIGRATION: Add missing tables and columns
-- Run this in the Turso SQL editor (one paste, one click).
-- Safe to run multiple times — all statements are idempotent.
-- ============================================================

-- 1. stock_movements — qty-product stock ledger
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

-- 2. ledger_entries — customer/supplier khata ledger
CREATE TABLE IF NOT EXISTS ledger_entries (
  id               TEXT PRIMARY KEY NOT NULL,
  owner_user_id    TEXT NOT NULL REFERENCES users (id),
  party_type       TEXT NOT NULL CHECK (party_type IN ('customer', 'supplier')),
  customer_id      TEXT REFERENCES customers (id),
  supplier_id      TEXT REFERENCES suppliers (id),
  amount           INTEGER NOT NULL,
  reason           TEXT NOT NULL,
  ref_purchase_id  TEXT REFERENCES purchases (id),
  ref_payment_id   TEXT REFERENCES payments (id),
  ref_invoice_id   TEXT REFERENCES invoices (id),
  notes            TEXT,
  created_by       TEXT REFERENCES users (id),
  occurred_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  deleted_at       TEXT
);

CREATE INDEX IF NOT EXISTS ledger_entries_customer_idx
  ON ledger_entries (owner_user_id, customer_id);
CREATE INDEX IF NOT EXISTS ledger_entries_supplier_idx
  ON ledger_entries (owner_user_id, supplier_id);

-- 3. Add deleted_at to payments (used by payments page filter)
ALTER TABLE payments ADD COLUMN deleted_at TEXT;
