-- ============================================================
--  CODEFLYX POS — Turso SQL Editor Version
--  Paste this entire file into the Turso SQL editor and run.
--  PRAGMA lines removed — Turso manages those internally.
--  All statements use IF NOT EXISTS — safe to re-run anytime.
-- ============================================================


CREATE TABLE IF NOT EXISTS users (
  id           TEXT PRIMARY KEY NOT NULL,
  full_name    TEXT NOT NULL,
  username     TEXT NOT NULL,
  password     TEXT NOT NULL,
  role         TEXT NOT NULL DEFAULT 'admin'
               CHECK (role IN ('admin', 'cashier')),
  phone        TEXT,
  email        TEXT,
  is_active    INTEGER NOT NULL DEFAULT 1
               CHECK (is_active IN (0, 1)),
  created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS users_username_uq ON users (username);


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
  invoice_prefix       TEXT NOT NULL DEFAULT 'INV',
  purchase_prefix      TEXT NOT NULL DEFAULT 'PUR',
  receipt_footer_text  TEXT,
  created_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);


CREATE TABLE IF NOT EXISTS document_counters (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),
  doc_type      TEXT NOT NULL,
  prefix        TEXT NOT NULL,
  next_no       INTEGER NOT NULL DEFAULT 1,
  padding       INTEGER NOT NULL DEFAULT 6,
  updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS doc_counters_owner_type_uq
  ON document_counters (owner_user_id, doc_type);


CREATE TABLE IF NOT EXISTS categories (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),
  name          TEXT NOT NULL,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS categories_owner_name_uq
  ON categories (owner_user_id, name);


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
  network_type           TEXT,
  os                     TEXT,
  tags                   TEXT,
  is_active              INTEGER NOT NULL DEFAULT 1
                         CHECK (is_active IN (0, 1)),
  deleted_at             TEXT,
  created_at             TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at             TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS products_owner_serial_uq
  ON products (owner_user_id, serial_no);

CREATE UNIQUE INDEX IF NOT EXISTS products_owner_sku_uq
  ON products (owner_user_id, sku)
  WHERE sku IS NOT NULL;


CREATE TABLE IF NOT EXISTS product_stock (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),
  product_id    TEXT NOT NULL REFERENCES products (id),
  quantity      INTEGER NOT NULL DEFAULT 0,
  updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS product_stock_product_uq
  ON product_stock (product_id);


CREATE TABLE IF NOT EXISTS customers (
  id              TEXT PRIMARY KEY NOT NULL,
  owner_user_id   TEXT NOT NULL REFERENCES users (id),
  name            TEXT NOT NULL,
  phone           TEXT,
  alternate_phone TEXT,
  cnic            TEXT,
  address         TEXT,
  credit_limit    INTEGER NOT NULL DEFAULT 0,
  notes           TEXT,
  deleted_at      TEXT,
  created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS customers_owner_phone_idx
  ON customers (owner_user_id, phone);


CREATE TABLE IF NOT EXISTS customer_documents (
  id             TEXT PRIMARY KEY NOT NULL,
  customer_id    TEXT NOT NULL REFERENCES customers (id),
  document_type  TEXT NOT NULL,
  file_url       TEXT NOT NULL,
  notes          TEXT,
  created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);


CREATE TABLE IF NOT EXISTS suppliers (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),
  name          TEXT NOT NULL,
  phone         TEXT,
  cnic          TEXT,
  address       TEXT,
  company_name  TEXT,
  notes         TEXT,
  deleted_at    TEXT,
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);


CREATE TABLE IF NOT EXISTS supplier_documents (
  id             TEXT PRIMARY KEY NOT NULL,
  supplier_id    TEXT NOT NULL REFERENCES suppliers (id),
  document_type  TEXT NOT NULL,
  file_url       TEXT NOT NULL,
  notes          TEXT,
  created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);


CREATE TABLE IF NOT EXISTS purchases (
  id                   TEXT PRIMARY KEY NOT NULL,
  owner_user_id        TEXT NOT NULL REFERENCES users (id),
  purchase_no          TEXT NOT NULL,
  kind                 TEXT NOT NULL DEFAULT 'supplier'
                       CHECK (kind IN ('supplier', 'trade_in')),
  type                 TEXT NOT NULL DEFAULT 'purchase'
                       CHECK (type IN ('purchase', 'return')),
  original_purchase_id TEXT REFERENCES purchases (id),
  supplier_id          TEXT REFERENCES suppliers (id),
  customer_id          TEXT REFERENCES customers (id),
  subtotal             INTEGER NOT NULL DEFAULT 0,
  discount             INTEGER NOT NULL DEFAULT 0,
  total                INTEGER NOT NULL DEFAULT 0,
  paid_total           INTEGER NOT NULL DEFAULT 0,
  status               TEXT NOT NULL DEFAULT 'completed'
                       CHECK (status IN ('completed', 'partial', 'pending', 'cancelled')),
  notes                TEXT,
  created_by           TEXT REFERENCES users (id),
  occurred_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  created_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  deleted_at           TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS purchases_owner_no_uq
  ON purchases (owner_user_id, purchase_no);


CREATE TABLE IF NOT EXISTS invoices (
  id                   TEXT PRIMARY KEY NOT NULL,
  owner_user_id        TEXT NOT NULL REFERENCES users (id),
  invoice_no           TEXT NOT NULL,
  type                 TEXT NOT NULL DEFAULT 'sale'
                       CHECK (type IN ('sale', 'return')),
  original_invoice_id  TEXT REFERENCES invoices (id),
  customer_id          TEXT REFERENCES customers (id),
  sale_mode            TEXT NOT NULL DEFAULT 'cash'
                       CHECK (sale_mode IN ('cash', 'jazzcash', 'easypaisa', 'bank_transfer', 'credit', 'mixed')),
  subtotal             INTEGER NOT NULL DEFAULT 0,
  discount             INTEGER NOT NULL DEFAULT 0,
  tax_total            INTEGER NOT NULL DEFAULT 0,
  total                INTEGER NOT NULL DEFAULT 0,
  paid_total           INTEGER NOT NULL DEFAULT 0,
  change_due           INTEGER NOT NULL DEFAULT 0,
  status               TEXT NOT NULL DEFAULT 'completed'
                       CHECK (status IN ('completed', 'partial', 'pending', 'cancelled')),
  void_reason          TEXT,
  notes                TEXT,
  created_by           TEXT REFERENCES users (id),
  occurred_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  created_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  deleted_at           TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS invoices_owner_no_uq
  ON invoices (owner_user_id, invoice_no);

CREATE INDEX IF NOT EXISTS invoices_customer_idx
  ON invoices (customer_id);


CREATE TABLE IF NOT EXISTS purchase_items (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),
  purchase_id   TEXT NOT NULL REFERENCES purchases (id),
  product_id    TEXT NOT NULL REFERENCES products (id),
  imei_unit_id  TEXT REFERENCES imei_units (id),
  qty           INTEGER NOT NULL DEFAULT 1,
  unit_cost     INTEGER NOT NULL DEFAULT 0,
  line_total    INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS purchase_items_purchase_idx
  ON purchase_items (purchase_id);


CREATE TABLE IF NOT EXISTS imei_units (
  id                    TEXT PRIMARY KEY NOT NULL,
  owner_user_id         TEXT NOT NULL REFERENCES users (id),
  product_id            TEXT NOT NULL REFERENCES products (id),
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
                        CHECK (pta_status IN ('approved', 'non-pta', 'pending')),
  battery_health        INTEGER,
  purchase_price        INTEGER NOT NULL DEFAULT 0,
  selling_price         INTEGER,
  source                TEXT NOT NULL DEFAULT 'supplier'
                        CHECK (source IN ('supplier', 'trade_in')),
  status                TEXT NOT NULL DEFAULT 'in_stock'
                        CHECK (status IN ('in_stock', 'sold', 'returned', 'defective')),
  sold_invoice_id       TEXT REFERENCES invoices (id),
  notes                 TEXT,
  created_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS imei_units_owner_imei_uq
  ON imei_units (owner_user_id, imei);

CREATE INDEX IF NOT EXISTS imei_units_product_status_idx
  ON imei_units (product_id, status);


CREATE TABLE IF NOT EXISTS invoice_items (
  id                   TEXT PRIMARY KEY NOT NULL,
  owner_user_id        TEXT NOT NULL REFERENCES users (id),
  invoice_id           TEXT NOT NULL REFERENCES invoices (id),
  product_id           TEXT NOT NULL REFERENCES products (id),
  imei_unit_id         TEXT REFERENCES imei_units (id),
  qty                  INTEGER NOT NULL DEFAULT 1,
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


CREATE TABLE IF NOT EXISTS payments (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),
  direction     TEXT NOT NULL DEFAULT 'in'
                CHECK (direction IN ('in', 'out')),
  method        TEXT NOT NULL DEFAULT 'cash'
                CHECK (method IN ('cash', 'jazzcash', 'easypaisa', 'bank_transfer')),
  amount        INTEGER NOT NULL,
  invoice_id    TEXT REFERENCES invoices (id),
  purchase_id   TEXT REFERENCES purchases (id),
  reference_no  TEXT,
  notes         TEXT,
  received_by   TEXT REFERENCES users (id),
  occurred_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS payments_invoice_idx  ON payments (invoice_id);
CREATE INDEX IF NOT EXISTS payments_purchase_idx ON payments (purchase_id);
