-- ============================================================
--  CODEFLYX POS — Turso / LibSQL Schema  (V1)
--  Compatible with: libsql / SQLite syntax
--  Money unit: PKR whole rupees (no decimals)
--  ID strategy: ULID strings (TEXT PRIMARY KEY)
--  All timestamps: ISO-8601 TEXT (e.g. '2026-04-06T10:30:00Z')
-- ============================================================

PRAGMA foreign_keys = ON;
PRAGMA journal_mode    = WAL;
PRAGMA synchronous     = NORMAL;
PRAGMA temp_store      = MEMORY;


-- ============================================================
-- 1. USERS  (auth + staff accounts)
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


-- ============================================================
-- 2. SHOP SETTINGS
-- ============================================================
-- One row per shop. Kept separate from users so deleting a
-- user never breaks historical invoice headers.

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


-- ============================================================
-- 3. DOCUMENT COUNTERS
-- ============================================================
-- Generates human-readable numbers: INV-000001, PUR-000001.
-- Flow: read next_no → format → INSERT doc → UPDATE next_no + 1.
-- doc_type: 'invoice' | 'purchase' | 'return_sale' | 'return_purchase'
-- App also uses this for product serial numbers (doc_type='product').

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


-- ============================================================
-- 4. CATEGORIES
-- ============================================================

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


-- ============================================================
-- 5. PRODUCTS
-- ============================================================
-- stock_tracking_type:
--   'imei'     → each unit tracked individually in imei_units
--   'quantity' → bulk stock tracked in product_stock
-- serial_no: auto-assigned by app (MAX + 1 in a transaction).
--   Used for quick lookup — search "12" to find product #12.
-- color_options / storage_options / ram_options: JSON arrays as TEXT.

CREATE TABLE IF NOT EXISTS products (
  id                     TEXT PRIMARY KEY NOT NULL,
  owner_user_id          TEXT NOT NULL REFERENCES users (id),
  category_id            TEXT REFERENCES categories (id),

  serial_no              INTEGER NOT NULL DEFAULT 0,  -- auto-assigned, shop-scoped

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

  -- JSON arrays, e.g. '["Black","White"]'
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


-- ============================================================
-- 6. PRODUCT STOCK  (quantity-type products only)
-- ============================================================
-- IMEI products don't use this — their stock = count of
-- imei_units WHERE status = 'in_stock'.

CREATE TABLE IF NOT EXISTS product_stock (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),
  product_id    TEXT NOT NULL REFERENCES products (id),

  quantity      INTEGER NOT NULL DEFAULT 0,

  updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS product_stock_product_uq
  ON product_stock (product_id);


-- ============================================================
-- 7. IMEI UNITS  (individual mobile units — IMEI-tracked)
-- ============================================================
-- source:
--   'supplier'  → bought from supplier (purchase_item_id set)
--   'trade_in'  → bought from customer (trade_in_customer_id set)
-- status flow: in_stock → sold | returned | defective
-- selling_price: per-unit override; NULL = use products.sale_price.
--   Useful for used/refurbished phones priced individually.

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
  ram_rom               TEXT,  -- e.g. '8GB/256GB'

  condition             TEXT NOT NULL DEFAULT 'new'
                        CHECK (condition IN ('new', 'used', 'refurbished')),
  pta_status            TEXT NOT NULL DEFAULT 'approved'
                        CHECK (pta_status IN ('approved', 'non-pta', 'pending')),

  battery_health        INTEGER,  -- percentage, 0-100

  -- money: PKR whole rupees
  purchase_price        INTEGER NOT NULL DEFAULT 0,
  selling_price         INTEGER,  -- NULL = use products.sale_price

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


-- ============================================================
-- 8. CUSTOMERS
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
  credit_limit    INTEGER NOT NULL DEFAULT 0,  -- 0 = no credit allowed

  notes           TEXT,

  deleted_at      TEXT,  -- soft delete; NULL = active

  created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS customers_owner_phone_idx
  ON customers (owner_user_id, phone);


-- ============================================================
-- 9. CUSTOMER DOCUMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS customer_documents (
  id             TEXT PRIMARY KEY NOT NULL,
  customer_id    TEXT NOT NULL REFERENCES customers (id),

  document_type  TEXT NOT NULL,  -- 'cnic_front' | 'cnic_back' | 'agreement' | 'other'
  file_url       TEXT NOT NULL,
  notes          TEXT,

  created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);


-- ============================================================
-- 10. SUPPLIERS
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


-- ============================================================
-- 11. SUPPLIER DOCUMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS supplier_documents (
  id             TEXT PRIMARY KEY NOT NULL,
  supplier_id    TEXT NOT NULL REFERENCES suppliers (id),

  document_type  TEXT NOT NULL,  -- 'cnic_front' | 'cnic_back' | 'agreement' | 'other'
  file_url       TEXT NOT NULL,
  notes          TEXT,

  created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);


-- ============================================================
-- 12. PURCHASES  (stock in)
-- ============================================================
-- kind:
--   'supplier'  → buying stock from a supplier
--   'trade_in'  → buying a used device from a customer
-- type:
--   'purchase'  → normal stock purchase
--   'return'    → returning stock back (to supplier or customer)
-- For returns: original_purchase_id must be set.
-- customer_id: set when kind = 'trade_in'.
-- paid_total: sum of linked payments WHERE direction = 'out'.

CREATE TABLE IF NOT EXISTS purchases (
  id                   TEXT PRIMARY KEY NOT NULL,
  owner_user_id        TEXT NOT NULL REFERENCES users (id),

  purchase_no          TEXT NOT NULL,

  kind                 TEXT NOT NULL DEFAULT 'supplier'
                       CHECK (kind IN ('supplier', 'trade_in')),

  type                 TEXT NOT NULL DEFAULT 'purchase'
                       CHECK (type IN ('purchase', 'return')),
  original_purchase_id TEXT REFERENCES purchases (id),

  supplier_id          TEXT REFERENCES suppliers (id),   -- set when kind = 'supplier'
  customer_id          TEXT REFERENCES customers (id),   -- set when kind = 'trade_in'

  -- money: PKR whole rupees
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

  deleted_at           TEXT  -- soft delete
);

CREATE UNIQUE INDEX IF NOT EXISTS purchases_owner_no_uq
  ON purchases (owner_user_id, purchase_no);


-- ============================================================
-- 13. PURCHASE ITEMS
-- ============================================================
-- imei_unit_id: set for IMEI-type products.
-- For quantity-type products: imei_unit_id is NULL.

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


-- ============================================================
-- 14. INVOICES  (sales)
-- ============================================================
-- type:
--   'sale'   → normal sale to customer
--   'return' → customer returning item (refund)
-- For returns: original_invoice_id must be set.
-- sale_mode: snapshot of how this sale was paid — avoids
--   joining payments just to show the payment method in a list.
--   'credit' = khata/unpaid. 'mixed' = partial cash + partial credit.
--   A coarse enum on purpose: the precise method is on the payment row
--   (payments_new.method / payment_account_id). POS options with no value of
--   their own map onto the nearest one — "unpaid" is stored as 'credit', and a
--   complementary (free) sale as 'mixed', the only value naming no real
--   account, with method 'complementary' on its payment row and a matching
--   expense under the "Complementary" category.
-- void_reason: populated when status = 'cancelled'.
-- paid_total: sum of linked payments WHERE direction = 'in'.

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

  -- money: PKR whole rupees
  subtotal             INTEGER NOT NULL DEFAULT 0,
  discount             INTEGER NOT NULL DEFAULT 0,
  tax_total            INTEGER NOT NULL DEFAULT 0,
  total                INTEGER NOT NULL DEFAULT 0,
  paid_total           INTEGER NOT NULL DEFAULT 0,
  change_due           INTEGER NOT NULL DEFAULT 0,

  status               TEXT NOT NULL DEFAULT 'completed'
                       CHECK (status IN ('completed', 'partial', 'pending', 'cancelled')),

  void_reason          TEXT,  -- reason for cancellation; NULL if not voided

  notes                TEXT,
  created_by           TEXT REFERENCES users (id),

  occurred_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  created_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),

  deleted_at           TEXT  -- soft delete
);

CREATE UNIQUE INDEX IF NOT EXISTS invoices_owner_no_uq
  ON invoices (owner_user_id, invoice_no);

CREATE INDEX IF NOT EXISTS invoices_customer_idx
  ON invoices (customer_id);


-- ============================================================
-- 15. INVOICE ITEMS
-- ============================================================
-- unit_cost_at_sale: snapshot of purchase cost at time of sale
--   for profit margin calculation. Never update after insert.
-- warranty_expiry_date: computed by app = occurred_at + warranty_days.

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


-- ============================================================
-- 16. PAYMENTS
-- ============================================================
-- direction:
--   'in'  → money received (customer paying invoice)
--   'out' → money paid (you paying supplier / customer for trade-in)
-- Exactly one of invoice_id or purchase_id should be set.

CREATE TABLE IF NOT EXISTS payments (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),

  direction     TEXT NOT NULL DEFAULT 'in'
                CHECK (direction IN ('in', 'out')),

  method        TEXT NOT NULL DEFAULT 'cash'
                CHECK (method IN ('cash', 'jazzcash', 'easypaisa', 'bank_transfer')),

  -- money: PKR whole rupees
  amount        INTEGER NOT NULL,

  invoice_id    TEXT REFERENCES invoices (id),
  purchase_id   TEXT REFERENCES purchases (id),

  reference_no  TEXT,  -- bank txn ID, JazzCash ref, cheque no, etc.
  notes         TEXT,

  received_by   TEXT REFERENCES users (id),

  occurred_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS payments_invoice_idx  ON payments (invoice_id);
CREATE INDEX IF NOT EXISTS payments_purchase_idx ON payments (purchase_id);


-- ============================================================
-- END OF SCHEMA  (V1 — Phase 1)
-- ============================================================
-- Tables: 16
-- Changes vs previous version:
--   ✓ products.serial_no added — app-assigned, shop-scoped integer
--   ✓ products_owner_serial_uq index added
--   ✓ products.deleted_at added — soft delete (was missing)
--   ✓ imei_units.selling_price added — per-unit price override
--   ✓ purchases.kind added — 'supplier' | 'trade_in'
--   ✓ purchases.customer_id added — for trade-in purchases
--   ✓ purchases.notes added — was missing
--   ✓ invoices.sale_mode added back — payment snapshot for display
--   ✓ invoices.void_reason added — reason when status='cancelled'
-- ============================================================
