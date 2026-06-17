-- ============================================================
-- TABLE: products
-- Purpose: Product catalog — the master list of all items sold.
-- stock_tracking_type:
--   'imei'     → each unit tracked individually via imei_units
--   'quantity' → bulk count tracked via product_stock
-- serial_no: shop-scoped auto integer (1, 2, 3 …).
--   App assigns it: SELECT COALESCE(MAX(serial_no),0)+1
--   FROM products WHERE owner_user_id=? inside a transaction.
--   Used for fast POS search — cashier types "42" to find product #42.
-- selling_price options per IMEI unit live in imei_units.selling_price.
-- color_options / storage_options / ram_options: JSON arrays as TEXT.
--   e.g. '["Black","White"]' — query with LIKE or JSON functions.
-- deleted_at: soft delete — never hard-delete; historical invoice
--   items reference product_id for display.
-- ============================================================

CREATE TABLE IF NOT EXISTS products (
  id                     TEXT PRIMARY KEY NOT NULL,
  owner_user_id          TEXT NOT NULL REFERENCES users (id),
  category_id            TEXT REFERENCES categories (id),

  serial_no              INTEGER NOT NULL DEFAULT 0,

  name                   TEXT NOT NULL,
  brand                  TEXT,
  model                  TEXT,

  sku                    TEXT,
  barcode                TEXT,

  stock_tracking_type    TEXT NOT NULL
                         CHECK (stock_tracking_type IN ('imei', 'quantity')),

  -- money: PKR whole rupees
  sale_price             INTEGER NOT NULL DEFAULT 0,
  min_sale_price         INTEGER NOT NULL DEFAULT 0,
  default_purchase_price INTEGER NOT NULL DEFAULT 0,

  low_stock_alert        INTEGER NOT NULL DEFAULT 0,
  warranty_days          INTEGER NOT NULL DEFAULT 0,

  image_url              TEXT,
  description            TEXT,

  color_options          TEXT NOT NULL DEFAULT '[]',
  storage_options        TEXT NOT NULL DEFAULT '[]',
  ram_options            TEXT NOT NULL DEFAULT '[]',

  network_type           TEXT,  -- '4G' | '5G' | 'dual-sim' etc.
  os                     TEXT,  -- 'Android' | 'iOS' etc.
  tags                   TEXT,  -- comma-separated or JSON

  is_active              INTEGER NOT NULL DEFAULT 1
                         CHECK (is_active IN (0, 1)),

  deleted_at             TEXT,  -- soft delete; NULL = active

  created_at             TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at             TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS products_owner_serial_uq
  ON products (owner_user_id, serial_no);

CREATE UNIQUE INDEX IF NOT EXISTS products_owner_sku_uq
  ON products (owner_user_id, sku)
  WHERE sku IS NOT NULL;
