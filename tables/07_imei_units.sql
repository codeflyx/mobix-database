-- ============================================================
-- TABLE: imei_units
-- Purpose: Tracks every individual mobile unit by IMEI number.
--   Only used for products with stock_tracking_type = 'imei'.
-- source:
--   'supplier'  → unit came from a supplier purchase
--   'trade_in'  → unit bought from a customer
-- status flow:
--   in_stock → sold | returned | defective | damaged | lost
-- selling_price: per-unit override. NULL = use products.sale_price.
-- purchase_price: what was paid for this unit (profit calc).
-- deleted_at: soft delete — NULL = active.
-- ============================================================

CREATE TABLE IF NOT EXISTS imei_units (
  id                    TEXT PRIMARY KEY NOT NULL,
  owner_user_id         TEXT NOT NULL REFERENCES users (id),
  product_id            TEXT NOT NULL REFERENCES products (id),

  purchase_id           TEXT REFERENCES purchases (id),
  purchase_item_id      TEXT REFERENCES purchase_items (id),
  trade_in_customer_id  TEXT REFERENCES customers (id),

  imei                  TEXT NOT NULL,
  imei2                 TEXT,
  serial_no             TEXT,

  color                 TEXT,
  ram_rom               TEXT,

  condition             TEXT NOT NULL DEFAULT 'new'
                        CHECK (condition IN ('new', 'used', 'refurbished')),

  pta_status            TEXT NOT NULL DEFAULT 'approved'
                        CHECK (pta_status IN ('approved', 'non_pta', 'cpid', 'unknown')),

  battery_health        INTEGER,

  -- money: PKR whole rupees
  purchase_price        INTEGER NOT NULL DEFAULT 0,
  selling_price         INTEGER,

  warranty_days         INTEGER NOT NULL DEFAULT 0,

  source                TEXT NOT NULL DEFAULT 'supplier'
                        CHECK (source IN ('supplier', 'trade_in', 'adjustment')),

  status                TEXT NOT NULL DEFAULT 'in_stock'
                        CHECK (status IN ('in_stock', 'sold', 'returned', 'defective', 'damaged', 'lost')),

  sold_invoice_id       TEXT REFERENCES invoices (id),

  notes                 TEXT,

  created_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  deleted_at            TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS imei_units_owner_imei_uq
  ON imei_units (owner_user_id, imei);

CREATE INDEX IF NOT EXISTS imei_units_product_status_idx
  ON imei_units (product_id, status);

CREATE INDEX IF NOT EXISTS imei_units_purchase_idx
  ON imei_units (purchase_id);
