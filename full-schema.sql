-- ============================================================================
-- MobiPOS — full database schema (structure only, NO data)
-- Exported from the live Turso databases on 2026-10-19:
-- the main "mobipos" database merged with every shop (tenant) database, so each
-- table has every column that exists anywhere.
-- Tables: 47   Indexes: 48   Views: 0   Triggers: 0
--
-- Every statement uses IF NOT EXISTS, so it is safe to run more than once.
-- Run it on the new database with:
--   turso db shell <new-db-name> < full-schema.sql
-- or paste the whole file into the Turso dashboard SQL editor.
-- ============================================================================

PRAGMA foreign_keys = OFF;

-- ----------------------------------------------------------------------------
-- TABLES
-- ----------------------------------------------------------------------------

-- table: users
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
, parent_admin_id TEXT, staff_role TEXT, permissions TEXT);

-- table: shop_settings
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

-- table: document_counters
CREATE TABLE IF NOT EXISTS document_counters (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),
  doc_type      TEXT NOT NULL,
  prefix        TEXT NOT NULL,
  next_no       INTEGER NOT NULL DEFAULT 1,
  padding       INTEGER NOT NULL DEFAULT 4,
  updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- table: categories
CREATE TABLE IF NOT EXISTS categories (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),
  name          TEXT NOT NULL,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- table: products
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
, product_images TEXT NOT NULL DEFAULT '[]');

-- table: product_stock
CREATE TABLE IF NOT EXISTS product_stock (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),
  product_id    TEXT NOT NULL REFERENCES products (id),
  quantity      INTEGER NOT NULL DEFAULT 0,
  updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
, variant_id TEXT REFERENCES product_variants (id));

-- table: customers
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

-- table: customer_documents
CREATE TABLE IF NOT EXISTS customer_documents (
  id             TEXT PRIMARY KEY NOT NULL,
  customer_id    TEXT NOT NULL REFERENCES customers (id),
  document_type  TEXT NOT NULL,
  file_url       TEXT NOT NULL,
  notes          TEXT,
  created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- table: suppliers
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

-- table: supplier_documents
CREATE TABLE IF NOT EXISTS supplier_documents (
  id             TEXT PRIMARY KEY NOT NULL,
  supplier_id    TEXT NOT NULL REFERENCES suppliers (id),
  document_type  TEXT NOT NULL,
  file_url       TEXT NOT NULL,
  notes          TEXT,
  created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- table: purchases
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
, supplier_invoice_ref   TEXT, expected_delivery_date TEXT, currency               TEXT DEFAULT 'PKR', exchange_rate          REAL DEFAULT 1, approval_status TEXT DEFAULT 'draft', approval_by     TEXT, approval_at     TEXT, approval_notes  TEXT, images TEXT NOT NULL DEFAULT '[]');

-- table: invoices
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
, sold_by_staff_id TEXT REFERENCES staff (id));

-- table: purchase_items
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
, sale_price INTEGER DEFAULT 0, is_mobile INTEGER DEFAULT 0, imei TEXT, ram TEXT, rom TEXT, color TEXT, variant_id TEXT REFERENCES product_variants (id));

-- table: imei_units
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
, purchase_id TEXT REFERENCES purchases (id), warranty_days INTEGER NOT NULL DEFAULT 0, deleted_at TEXT, variant_id TEXT REFERENCES product_variants (id));

-- table: invoice_items
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
, variant_id TEXT REFERENCES product_variants (id));

-- table: stock_movements
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
, variant_id TEXT REFERENCES product_variants (id));

-- table: expenses
CREATE TABLE IF NOT EXISTS expenses (
  id               TEXT PRIMARY KEY NOT NULL,
  owner_user_id    TEXT NOT NULL REFERENCES users (id),

  -- money: PKR stored as paisa (rupees * 100), matching the rest of the app
  amount           INTEGER NOT NULL,

  category_name    TEXT,             -- free-text, grouped in the P&L report
  subcategory_name TEXT,             -- e.g. Electricity, Rent, Salary

  payment_method     TEXT NOT NULL DEFAULT 'cash',  -- free text: mirror of the payment account's method_key
  payment_account_id TEXT REFERENCES payment_accounts (id),

  vendor           TEXT,             -- who it was paid to
  receipt_no       TEXT,             -- bill / receipt reference
  notes            TEXT,

  created_by       TEXT REFERENCES users (id),

  occurred_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  deleted_at       TEXT,             -- soft delete; NULL = active
  created_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- table: payment_accounts
CREATE TABLE IF NOT EXISTS payment_accounts (
  id              TEXT PRIMARY KEY NOT NULL,
  owner_user_id   TEXT NOT NULL REFERENCES users (id),

  method_key      TEXT,                          -- 'cash','jazzcash','easypaisa','bank', or custom slug; NULL = pure manual
  account_title   TEXT NOT NULL,                 -- display name: "Cash Drawer", "Meezan Bank"
  account_number  TEXT,                          -- IBAN / wallet number / free label
  notes           TEXT,

  -- money: PKR stored as paisa (rupees * 100)
  opening_balance INTEGER NOT NULL DEFAULT 0,
  current_balance INTEGER NOT NULL DEFAULT 0,    -- maintained by the ledger in a later phase

  is_system       INTEGER NOT NULL DEFAULT 0 CHECK (is_system IN (0, 1)),   -- 1 = default, cannot be deleted
  is_active       INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  sort_order      INTEGER NOT NULL DEFAULT 0,

  created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  deleted_at      TEXT
);

-- table: payments_new
CREATE TABLE IF NOT EXISTS payments_new (
  id                 TEXT PRIMARY KEY NOT NULL,
  owner_user_id      TEXT NOT NULL REFERENCES users (id),
  direction          TEXT NOT NULL DEFAULT 'in' CHECK (direction IN ('in', 'out')),
  method             TEXT NOT NULL DEFAULT 'cash',   -- free text now: mirror of the account's method_key
  amount             INTEGER NOT NULL,
  invoice_id         TEXT REFERENCES invoices (id),
  purchase_id        TEXT REFERENCES purchases (id),
  payment_account_id TEXT REFERENCES payment_accounts (id),
  reference_no       TEXT,
  notes              TEXT,
  received_by        TEXT REFERENCES users (id),
  occurred_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  created_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  deleted_at         TEXT
, repair_id TEXT, easyload_id TEXT);

-- table: ledger_entries
CREATE TABLE IF NOT EXISTS "ledger_entries" (
    id               TEXT PRIMARY KEY NOT NULL,
    owner_user_id    TEXT NOT NULL REFERENCES users (id),
    party_type       TEXT NOT NULL CHECK (party_type IN ('customer', 'supplier')),
    customer_id      TEXT REFERENCES customers (id),
    supplier_id      TEXT REFERENCES suppliers (id),
    amount           INTEGER NOT NULL,
    reason           TEXT NOT NULL,
    ref_purchase_id  TEXT REFERENCES purchases (id),
    ref_payment_id   TEXT,
    ref_invoice_id   TEXT REFERENCES invoices (id),
    notes            TEXT,
    created_by       TEXT REFERENCES users (id),
    occurred_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    deleted_at       TEXT
  , ref_repair_id TEXT, ref_easyload_id TEXT);

-- table: purchase_returns
CREATE TABLE IF NOT EXISTS purchase_returns (
      id                     TEXT PRIMARY KEY,
      owner_user_id          TEXT NOT NULL,
      return_no              TEXT NOT NULL,
      purchase_id            TEXT,
      supplier_id            TEXT NOT NULL,
      return_type            TEXT NOT NULL DEFAULT 'refund',
      return_reason          TEXT NOT NULL,
      return_date            TEXT NOT NULL,
      warehouse              TEXT,
      supplier_credit_note_no TEXT,
      remarks                TEXT,
      total_return_value     INTEGER NOT NULL DEFAULT 0,
      status                 TEXT NOT NULL DEFAULT 'pending',
      refund_method          TEXT,
      refund_amount          INTEGER DEFAULT 0,
      refund_notes           TEXT,
      created_by             TEXT,
      approved_by            TEXT,
      approved_at            TEXT,
      approval_notes         TEXT,
      rejection_reason       TEXT,
      occurred_at            TEXT NOT NULL,
      created_at             TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at             TEXT NOT NULL DEFAULT (datetime('now')),
      UNIQUE(owner_user_id, return_no)
    );

-- table: purchase_return_items
CREATE TABLE IF NOT EXISTS purchase_return_items (
      id             TEXT PRIMARY KEY,
      owner_user_id  TEXT NOT NULL,
      return_id      TEXT NOT NULL,
      product_id     TEXT NOT NULL,
      qty            INTEGER NOT NULL DEFAULT 0,
      unit_cost      INTEGER NOT NULL DEFAULT 0,
      return_value   INTEGER NOT NULL DEFAULT 0
    , variant_id TEXT REFERENCES product_variants (id));

-- table: purchase_return_imeis
CREATE TABLE IF NOT EXISTS purchase_return_imeis (
      id            TEXT PRIMARY KEY,
      owner_user_id TEXT NOT NULL,
      return_id     TEXT NOT NULL,
      return_item_id TEXT,
      imei_unit_id  TEXT NOT NULL,
      product_id    TEXT NOT NULL,
      imei          TEXT NOT NULL,
      unit_cost     INTEGER NOT NULL DEFAULT 0
    );

-- table: sale_orders
CREATE TABLE IF NOT EXISTS sale_orders (
          id                     TEXT PRIMARY KEY,
          owner_user_id          TEXT NOT NULL,
          order_no               TEXT NOT NULL,
          customer_id            TEXT,
          customer_name          TEXT,
          customer_mobile        TEXT,
          customer_cnic          TEXT,
          salesman_id            TEXT,
          branch                 TEXT,
          order_date             TEXT NOT NULL,
          expected_delivery_date TEXT,
          subtotal               INTEGER NOT NULL DEFAULT 0,
          discount_amount        INTEGER NOT NULL DEFAULT 0,
          total_amount           INTEGER NOT NULL DEFAULT 0,
          advance_paid           INTEGER NOT NULL DEFAULT 0,
          balance_due            INTEGER NOT NULL DEFAULT 0,
          status                 TEXT NOT NULL DEFAULT 'pending',
          remarks                TEXT,
          approved_by            TEXT,
          approved_at            TEXT,
          approval_notes         TEXT,
          rejection_reason       TEXT,
          created_by             TEXT,
          occurred_at            TEXT NOT NULL,
          created_at             TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at             TEXT NOT NULL DEFAULT (datetime('now')),
          UNIQUE(owner_user_id, order_no)
        );

-- table: sale_order_items
CREATE TABLE IF NOT EXISTS sale_order_items (
          id               TEXT PRIMARY KEY,
          owner_user_id    TEXT NOT NULL,
          order_id         TEXT NOT NULL,
          product_id       TEXT NOT NULL,
          color            TEXT,
          storage_variant  TEXT,
          warranty_type    TEXT,
          qty_ordered      INTEGER NOT NULL DEFAULT 0,
          qty_reserved     INTEGER NOT NULL DEFAULT 0,
          qty_delivered    INTEGER NOT NULL DEFAULT 0,
          unit_price       INTEGER NOT NULL DEFAULT 0,
          discount_pct     REAL DEFAULT 0,
          flat_discount    INTEGER DEFAULT 0,
          net_price        INTEGER NOT NULL DEFAULT 0,
          line_total       INTEGER NOT NULL DEFAULT 0
        , variant_id TEXT REFERENCES product_variants (id));

-- table: sale_order_imeis
CREATE TABLE IF NOT EXISTS sale_order_imeis (
          id             TEXT PRIMARY KEY,
          owner_user_id  TEXT NOT NULL,
          order_id       TEXT NOT NULL,
          order_item_id  TEXT,
          imei_unit_id   TEXT NOT NULL,
          product_id     TEXT NOT NULL,
          imei           TEXT NOT NULL,
          unit_price     INTEGER NOT NULL DEFAULT 0,
          status         TEXT NOT NULL DEFAULT 'pending'
        );

-- table: audit_logs
CREATE TABLE IF NOT EXISTS audit_logs (
          id             TEXT PRIMARY KEY,
          owner_user_id  TEXT,
          actor_user_id  TEXT,
          action         TEXT NOT NULL,
          table_name     TEXT,
          row_id         TEXT,
          old_data       TEXT,
          new_data       TEXT,
          ip_address     TEXT,
          user_agent     TEXT,
          created_at     TEXT NOT NULL DEFAULT (datetime('now'))
        );

-- table: printers
CREATE TABLE IF NOT EXISTS printers (
  id                TEXT PRIMARY KEY NOT NULL,
  owner_user_id     TEXT NOT NULL REFERENCES users (id),
  name              TEXT NOT NULL,

  -- 'usb'         → serial/COM printer, print via `copy /b file COMx`
  -- 'windows_usb' → installed Windows printer (USB001), print via winspool RAW
  -- 'network'     → ESC/POS over TCP to ip_address:ip_port (usually 9100)
  connection_type   TEXT NOT NULL DEFAULT 'usb'
                    CHECK (connection_type IN ('usb', 'windows_usb', 'network')),

  usb_port          TEXT,            -- "COM3"  (connection_type = 'usb')
  usb_printer_name  TEXT,            -- Windows printer name (connection_type = 'windows_usb')
  ip_address        TEXT,            -- "192.168.1.50" (connection_type = 'network')
  ip_port           INTEGER,         -- 9100 (connection_type = 'network')

  paper_width       INTEGER NOT NULL DEFAULT 48,   -- chars per line: 32=58mm, 42=72mm, 48=80mm
  model             TEXT,

  is_default        INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1)),
  is_active         INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  last_connected_at TEXT,

  created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- table: receipt_settings
CREATE TABLE IF NOT EXISTS receipt_settings (
  id                  TEXT PRIMARY KEY NOT NULL,
  owner_user_id       TEXT NOT NULL UNIQUE REFERENCES users (id),

  -- Business info / text content
  store_name          TEXT,
  phone1              TEXT,
  phone2              TEXT,
  email               TEXT,
  address             TEXT,
  tagline_text        TEXT,
  thankyou_text       TEXT,
  footer_note_text    TEXT,
  branding_text       TEXT,

  -- Branding images (Cloudinary secure URLs) + print sizes (px width)
  logo_url            TEXT,
  qr_url              TEXT,
  logo_size           INTEGER NOT NULL DEFAULT 250,
  qr_size             INTEGER NOT NULL DEFAULT 200,

  -- Header toggles
  show_logo           INTEGER NOT NULL DEFAULT 1 CHECK (show_logo IN (0,1)),
  show_shop_name      INTEGER NOT NULL DEFAULT 1 CHECK (show_shop_name IN (0,1)),
  show_tagline        INTEGER NOT NULL DEFAULT 1 CHECK (show_tagline IN (0,1)),
  show_address        INTEGER NOT NULL DEFAULT 1 CHECK (show_address IN (0,1)),
  show_phone          INTEGER NOT NULL DEFAULT 1 CHECK (show_phone IN (0,1)),
  show_email          INTEGER NOT NULL DEFAULT 1 CHECK (show_email IN (0,1)),

  -- Transaction-detail toggles
  show_invoice_no     INTEGER NOT NULL DEFAULT 1 CHECK (show_invoice_no IN (0,1)),
  show_datetime       INTEGER NOT NULL DEFAULT 1 CHECK (show_datetime IN (0,1)),
  show_cashier        INTEGER NOT NULL DEFAULT 1 CHECK (show_cashier IN (0,1)),
  show_customer       INTEGER NOT NULL DEFAULT 1 CHECK (show_customer IN (0,1)),
  show_customer_phone INTEGER NOT NULL DEFAULT 1 CHECK (show_customer_phone IN (0,1)),
  show_payment_method INTEGER NOT NULL DEFAULT 1 CHECK (show_payment_method IN (0,1)),

  -- Footer toggles
  show_thankyou       INTEGER NOT NULL DEFAULT 1 CHECK (show_thankyou IN (0,1)),
  show_footer_note    INTEGER NOT NULL DEFAULT 1 CHECK (show_footer_note IN (0,1)),
  show_qr             INTEGER NOT NULL DEFAULT 1 CHECK (show_qr IN (0,1)),
  show_branding       INTEGER NOT NULL DEFAULT 1 CHECK (show_branding IN (0,1)),

  -- Print behaviour
  auto_print          INTEGER NOT NULL DEFAULT 1 CHECK (auto_print IN (0,1)),
  copies              INTEGER NOT NULL DEFAULT 1,
  beep                INTEGER NOT NULL DEFAULT 1 CHECK (beep IN (0,1)),

  created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  updated_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
, logo_library TEXT NOT NULL DEFAULT '[]', qr_library TEXT NOT NULL DEFAULT '[]');

-- table: pos_preferences
CREATE TABLE IF NOT EXISTS pos_preferences (
       owner_user_id          TEXT PRIMARY KEY NOT NULL REFERENCES users (id),
       show_account_balances  INTEGER NOT NULL DEFAULT 0,
       updated_at             TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
     , default_staff_id TEXT REFERENCES staff (id));

-- table: stock_adjustments
CREATE TABLE IF NOT EXISTS stock_adjustments (
  id             TEXT PRIMARY KEY NOT NULL,
  owner_user_id  TEXT NOT NULL REFERENCES users (id),
  adj_no         TEXT NOT NULL,
  reason_type    TEXT NOT NULL DEFAULT 'count_correction'
                 CHECK (reason_type IN (
                   'count_correction','damaged','found',
                   'opening_stock','write_off','transfer','other'
                 )),
  total_items    INTEGER NOT NULL DEFAULT 0,
  notes          TEXT,
  created_by     TEXT REFERENCES users (id),
  occurred_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- table: repairs
CREATE TABLE IF NOT EXISTS repairs (
     id              TEXT NOT NULL PRIMARY KEY,
     owner_user_id   TEXT NOT NULL,
     repair_no       TEXT NOT NULL,

     customer_id     TEXT,
     customer_name   TEXT,
     customer_phone  TEXT,

     device_type     TEXT NOT NULL DEFAULT 'phone',
     brand           TEXT,
     model           TEXT,
     imei            TEXT,
     color           TEXT,
     unlock_code     TEXT,
     accessories     TEXT,
     condition_notes TEXT,

     problem         TEXT NOT NULL,
     diagnosis       TEXT,
     technician_id   TEXT,

     status          TEXT NOT NULL DEFAULT 'received',
     priority        TEXT NOT NULL DEFAULT 'normal',

     estimate_total  INTEGER NOT NULL DEFAULT 0,
     parts_total     INTEGER NOT NULL DEFAULT 0,
     labor_total     INTEGER NOT NULL DEFAULT 0,
     discount        INTEGER NOT NULL DEFAULT 0,
     total           INTEGER NOT NULL DEFAULT 0,
     paid_total      INTEGER NOT NULL DEFAULT 0,
     warranty_days   INTEGER NOT NULL DEFAULT 0,

     received_at     TEXT,
     promised_at     TEXT,
     completed_at    TEXT,
     delivered_at    TEXT,

     notes           TEXT,
     created_by      TEXT,
     created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
     updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
     deleted_at      TEXT
   );

-- table: repair_items
CREATE TABLE IF NOT EXISTS repair_items (
     id            TEXT NOT NULL PRIMARY KEY,
     owner_user_id TEXT NOT NULL,
     repair_id     TEXT NOT NULL,
     kind          TEXT NOT NULL DEFAULT 'part',
     description   TEXT NOT NULL,
     product_id    TEXT,
     qty           INTEGER NOT NULL DEFAULT 1,
     unit_price    INTEGER NOT NULL DEFAULT 0,
     line_total    INTEGER NOT NULL DEFAULT 0,
     created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
   );

-- table: brands
CREATE TABLE IF NOT EXISTS brands (
      id            TEXT PRIMARY KEY NOT NULL,
      owner_user_id TEXT NOT NULL REFERENCES users (id),
      name          TEXT NOT NULL,
      sort_order    INTEGER NOT NULL DEFAULT 0,
      created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
      updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
    );

-- table: easyloads
CREATE TABLE IF NOT EXISTS easyloads (
     id              TEXT NOT NULL PRIMARY KEY,
     owner_user_id   TEXT NOT NULL,
     load_no         TEXT NOT NULL,

     customer_id     TEXT,
     customer_name   TEXT,
     customer_phone  TEXT,

     type            TEXT NOT NULL DEFAULT 'load',
     network         TEXT NOT NULL,
     mobile_number   TEXT NOT NULL,
     package_name    TEXT,

     amount          INTEGER NOT NULL DEFAULT 0,
     commission      INTEGER NOT NULL DEFAULT 0,
     total           INTEGER NOT NULL DEFAULT 0,
     paid_total      INTEGER NOT NULL DEFAULT 0,

     status          TEXT NOT NULL DEFAULT 'completed',

     notes           TEXT,
     created_by      TEXT,
     occurred_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
     created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
     updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
     deleted_at      TEXT
   );

-- table: old_sale_bills
CREATE TABLE IF NOT EXISTS old_sale_bills (
     id              TEXT NOT NULL PRIMARY KEY,
     owner_user_id   TEXT NOT NULL,
     bill_no         TEXT NOT NULL,

     customer_id     TEXT,
     customer_name   TEXT,
     customer_phone  TEXT,

     sale_date       TEXT NOT NULL,

     subtotal        INTEGER NOT NULL DEFAULT 0,
     discount        INTEGER NOT NULL DEFAULT 0,
     total           INTEGER NOT NULL DEFAULT 0,

     notes           TEXT,
     created_by      TEXT,
     created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
     updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
     deleted_at      TEXT
   );

-- table: old_sale_bill_items
CREATE TABLE IF NOT EXISTS old_sale_bill_items (
     id            TEXT NOT NULL PRIMARY KEY,
     owner_user_id TEXT NOT NULL,
     bill_id       TEXT NOT NULL,
     product_id    TEXT,
     description   TEXT NOT NULL,
     qty           INTEGER NOT NULL DEFAULT 1,
     unit_price    INTEGER NOT NULL DEFAULT 0,
     line_total    INTEGER NOT NULL DEFAULT 0,
     created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
   );

-- table: user_databases
CREATE TABLE IF NOT EXISTS user_databases (
          user_id        TEXT PRIMARY KEY REFERENCES users(id),
          db_name        TEXT NOT NULL UNIQUE,
          db_url         TEXT,
          db_token       TEXT,
          status         TEXT NOT NULL DEFAULT 'pending',
          error_message  TEXT,
          attempt_count  INTEGER NOT NULL DEFAULT 0,
          rows_copied    INTEGER,
          created_at     TEXT NOT NULL,
          updated_at     TEXT NOT NULL,
          provisioned_at TEXT
        );

-- table: website_configurations
CREATE TABLE IF NOT EXISTS website_configurations (
      id                    TEXT PRIMARY KEY NOT NULL,
      user_id               TEXT NOT NULL,

      store_name            TEXT NOT NULL,
      store_slug            TEXT NOT NULL,

      tagline               TEXT,
      description           TEXT,
      logo_url              TEXT,
      cover_image_url       TEXT,
      favicon_url           TEXT,
      theme_color           TEXT DEFAULT '#6d5efc',
      theme_color_2         TEXT,

      is_store_open         INTEGER NOT NULL DEFAULT 1 CHECK (is_store_open IN (0,1)),
      allow_delivery        INTEGER NOT NULL DEFAULT 1 CHECK (allow_delivery IN (0,1)),
      allow_pickup          INTEGER NOT NULL DEFAULT 1 CHECK (allow_pickup IN (0,1)),
      opening_time          TEXT,
      closing_time          TEXT,

      address               TEXT,
      city                  TEXT,
      support_phone         TEXT,
      support_email         TEXT,
      whatsapp_number       TEXT,

      facebook_url          TEXT,
      instagram_url         TEXT,
      tiktok_url            TEXT,
      youtube_url           TEXT,

      currency_code         TEXT NOT NULL DEFAULT 'PKR',
      currency_symbol       TEXT NOT NULL DEFAULT 'Rs',
      tax_percentage        REAL NOT NULL DEFAULT 0,
      delivery_fee          INTEGER NOT NULL DEFAULT 0,
      minimum_order_amount  INTEGER NOT NULL DEFAULT 0,
      free_delivery_above   INTEGER,

      meta_title            TEXT,
      meta_description      TEXT,
      maintenance_mode      INTEGER NOT NULL DEFAULT 0 CHECK (maintenance_mode IN (0,1)),

      created_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

-- table: super_admins
CREATE TABLE IF NOT EXISTS super_admins (
      id          TEXT PRIMARY KEY NOT NULL,
      full_name   TEXT NOT NULL,
      email       TEXT NOT NULL UNIQUE COLLATE NOCASE,
      password    TEXT NOT NULL,
      is_active   INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
      created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
      updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
    );

-- table: staff
CREATE TABLE IF NOT EXISTS staff (
        id           TEXT PRIMARY KEY NOT NULL,
        user_id      TEXT NOT NULL,
        full_name    TEXT NOT NULL,
        username     TEXT,
        password     TEXT NOT NULL,
        staff_role   TEXT,
        phone        TEXT,
        email        TEXT,
        permissions  TEXT,
        can_login    INTEGER NOT NULL DEFAULT 1 CHECK (can_login IN (0, 1)),
        is_active    INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
        updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
      );

-- table: web_orders
CREATE TABLE IF NOT EXISTS web_orders (
      id                TEXT PRIMARY KEY NOT NULL,
      owner_user_id     TEXT NOT NULL,
      order_number      TEXT NOT NULL,

      customer_name     TEXT NOT NULL,
      customer_phone    TEXT NOT NULL,
      customer_email    TEXT,

      order_type        TEXT NOT NULL DEFAULT 'delivery',
      address           TEXT,
      city              TEXT,
      payment_method    TEXT,
      notes             TEXT,

      subtotal          INTEGER NOT NULL DEFAULT 0,
      tax_amount        INTEGER NOT NULL DEFAULT 0,
      delivery_fee      INTEGER NOT NULL DEFAULT 0,
      total             INTEGER NOT NULL DEFAULT 0,
      item_count        INTEGER NOT NULL DEFAULT 0,

      status            TEXT NOT NULL DEFAULT 'pending',
      is_approved       INTEGER NOT NULL DEFAULT 0 CHECK (is_approved IN (0,1)),
      rejection_reason  TEXT,
      order_source      TEXT NOT NULL DEFAULT 'Website',

      created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

-- table: web_order_items
CREATE TABLE IF NOT EXISTS web_order_items (
      id            TEXT PRIMARY KEY NOT NULL,
      order_id      TEXT NOT NULL,
      owner_user_id TEXT NOT NULL,
      product_id    TEXT,
      name          TEXT NOT NULL,
      variant       TEXT,
      unit_price    INTEGER NOT NULL DEFAULT 0,
      qty           INTEGER NOT NULL DEFAULT 1,
      line_total    INTEGER NOT NULL DEFAULT 0
    , variant_id TEXT REFERENCES product_variants (id));

-- table: product_variants
CREATE TABLE IF NOT EXISTS product_variants (
      id              TEXT PRIMARY KEY NOT NULL,
      owner_user_id   TEXT NOT NULL REFERENCES users (id),
      product_id      TEXT NOT NULL REFERENCES products (id),

      name            TEXT NOT NULL,
      attrs           TEXT NOT NULL DEFAULT '{}',

      sku             TEXT,

      sale_price      INTEGER,
      min_sale_price  INTEGER,
      purchase_price  INTEGER,
      low_stock_alert INTEGER,

      track_serials   INTEGER NOT NULL DEFAULT 0 CHECK (track_serials IN (0,1)),

      is_default      INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0,1)),
      sort_order      INTEGER NOT NULL DEFAULT 0,
      is_active       INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),

      created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      deleted_at      TEXT
    );

-- table: barcodes
CREATE TABLE IF NOT EXISTS barcodes (
      id            TEXT PRIMARY KEY NOT NULL,
      owner_user_id TEXT NOT NULL REFERENCES users (id),

      code          TEXT NOT NULL,
      kind          TEXT NOT NULL DEFAULT 'variant' CHECK (kind IN ('variant','unit')),

      variant_id    TEXT REFERENCES product_variants (id),
      unit_id       TEXT REFERENCES imei_units (id),

      source        TEXT NOT NULL DEFAULT 'manual'
                    CHECK (source IN ('manual','supplier','printed','imported')),

      created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

-- table: item_labels
CREATE TABLE IF NOT EXISTS item_labels (
      id            TEXT PRIMARY KEY NOT NULL,
      owner_user_id TEXT NOT NULL REFERENCES users (id),

      code          TEXT NOT NULL,
      title         TEXT,

      symbology     TEXT NOT NULL DEFAULT 'code128'
                    CHECK (symbology IN ('code128', 'qrcode')),

      printed_at    TEXT,
      created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
    );

-- table: expense_categories
CREATE TABLE IF NOT EXISTS expense_categories (
      id            TEXT PRIMARY KEY NOT NULL,
      owner_user_id TEXT NOT NULL REFERENCES users (id),
      name          TEXT NOT NULL,
      is_system     INTEGER NOT NULL DEFAULT 0 CHECK (is_system IN (0,1)),
      sort_order    INTEGER NOT NULL DEFAULT 100,
      created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
      updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
      deleted_at    TEXT
    );

-- ----------------------------------------------------------------------------
-- INDEXS
-- ----------------------------------------------------------------------------

-- index: users_username_uq (on users)
CREATE UNIQUE INDEX IF NOT EXISTS users_username_uq ON users (username);

-- index: doc_counters_owner_type_uq (on document_counters)
CREATE UNIQUE INDEX IF NOT EXISTS doc_counters_owner_type_uq
  ON document_counters (owner_user_id, doc_type);

-- index: categories_owner_name_uq (on categories)
CREATE UNIQUE INDEX IF NOT EXISTS categories_owner_name_uq
  ON categories (owner_user_id, name);

-- index: products_owner_serial_uq (on products)
CREATE UNIQUE INDEX IF NOT EXISTS products_owner_serial_uq
  ON products (owner_user_id, serial_no);

-- index: products_owner_sku_uq (on products)
CREATE UNIQUE INDEX IF NOT EXISTS products_owner_sku_uq
  ON products (owner_user_id, sku)
  WHERE sku IS NOT NULL;

-- index: product_stock_product_uq (on product_stock)
CREATE UNIQUE INDEX IF NOT EXISTS product_stock_product_uq
  ON product_stock (product_id);

-- index: customers_owner_phone_idx (on customers)
CREATE INDEX IF NOT EXISTS customers_owner_phone_idx
  ON customers (owner_user_id, phone);

-- index: purchases_owner_no_uq (on purchases)
CREATE UNIQUE INDEX IF NOT EXISTS purchases_owner_no_uq
  ON purchases (owner_user_id, purchase_no);

-- index: invoices_owner_no_uq (on invoices)
CREATE UNIQUE INDEX IF NOT EXISTS invoices_owner_no_uq
  ON invoices (owner_user_id, invoice_no);

-- index: invoices_customer_idx (on invoices)
CREATE INDEX IF NOT EXISTS invoices_customer_idx
  ON invoices (customer_id);

-- index: purchase_items_purchase_idx (on purchase_items)
CREATE INDEX IF NOT EXISTS purchase_items_purchase_idx
  ON purchase_items (purchase_id);

-- index: imei_units_owner_imei_uq (on imei_units)
CREATE UNIQUE INDEX IF NOT EXISTS imei_units_owner_imei_uq
  ON imei_units (owner_user_id, imei);

-- index: imei_units_product_status_idx (on imei_units)
CREATE INDEX IF NOT EXISTS imei_units_product_status_idx
  ON imei_units (product_id, status);

-- index: invoice_items_invoice_idx (on invoice_items)
CREATE INDEX IF NOT EXISTS invoice_items_invoice_idx
  ON invoice_items (invoice_id);

-- index: invoice_items_warranty_idx (on invoice_items)
CREATE INDEX IF NOT EXISTS invoice_items_warranty_idx
  ON invoice_items (warranty_expiry_date)
  WHERE warranty_expiry_date IS NOT NULL;

-- index: stock_movements_product_idx (on stock_movements)
CREATE INDEX IF NOT EXISTS stock_movements_product_idx
  ON stock_movements (owner_user_id, product_id);

-- index: imei_units_purchase_idx (on imei_units)
CREATE INDEX IF NOT EXISTS imei_units_purchase_idx
  ON imei_units (purchase_id);

-- index: expenses_owner_date_idx (on expenses)
CREATE INDEX IF NOT EXISTS expenses_owner_date_idx
  ON expenses (owner_user_id, occurred_at);

-- index: expenses_owner_category_idx (on expenses)
CREATE INDEX IF NOT EXISTS expenses_owner_category_idx
  ON expenses (owner_user_id, category_name);

-- index: payment_accounts_owner_key_uq (on payment_accounts)
CREATE UNIQUE INDEX IF NOT EXISTS payment_accounts_owner_key_uq
  ON payment_accounts (owner_user_id, method_key)
  WHERE method_key IS NOT NULL AND deleted_at IS NULL;

-- index: printers_owner_idx (on printers)
CREATE INDEX IF NOT EXISTS printers_owner_idx ON printers (owner_user_id);

-- index: stock_adjustments_adj_no_uq (on stock_adjustments)
CREATE UNIQUE INDEX IF NOT EXISTS stock_adjustments_adj_no_uq
  ON stock_adjustments (owner_user_id, adj_no);

-- index: stock_adjustments_owner_idx (on stock_adjustments)
CREATE INDEX IF NOT EXISTS stock_adjustments_owner_idx
  ON stock_adjustments (owner_user_id, occurred_at);

-- index: idx_repairs_owner_status (on repairs)
CREATE INDEX IF NOT EXISTS idx_repairs_owner_status
     ON repairs (owner_user_id, status);

-- index: idx_repairs_owner_created (on repairs)
CREATE INDEX IF NOT EXISTS idx_repairs_owner_created
     ON repairs (owner_user_id, created_at);

-- index: idx_repairs_customer (on repairs)
CREATE INDEX IF NOT EXISTS idx_repairs_customer ON repairs (customer_id);

-- index: idx_repair_items_repair (on repair_items)
CREATE INDEX IF NOT EXISTS idx_repair_items_repair ON repair_items (repair_id);

-- index: brands_owner_name_uq (on brands)
CREATE UNIQUE INDEX IF NOT EXISTS brands_owner_name_uq ON brands (owner_user_id, name);

-- index: idx_easyloads_owner_created (on easyloads)
CREATE INDEX IF NOT EXISTS idx_easyloads_owner_created
     ON easyloads (owner_user_id, created_at);

-- index: idx_easyloads_owner_status (on easyloads)
CREATE INDEX IF NOT EXISTS idx_easyloads_owner_status
     ON easyloads (owner_user_id, status);

-- index: idx_easyloads_customer (on easyloads)
CREATE INDEX IF NOT EXISTS idx_easyloads_customer ON easyloads (customer_id);

-- index: idx_old_sale_bills_owner_created (on old_sale_bills)
CREATE INDEX IF NOT EXISTS idx_old_sale_bills_owner_created
     ON old_sale_bills (owner_user_id, created_at);

-- index: idx_old_sale_bills_customer (on old_sale_bills)
CREATE INDEX IF NOT EXISTS idx_old_sale_bills_customer ON old_sale_bills (customer_id);

-- index: idx_old_sale_bill_items_bill (on old_sale_bill_items)
CREATE INDEX IF NOT EXISTS idx_old_sale_bill_items_bill ON old_sale_bill_items (bill_id);

-- index: users_parent_admin_idx (on users)
CREATE INDEX IF NOT EXISTS users_parent_admin_idx ON users (parent_admin_id);

-- index: website_configurations_slug_uq (on website_configurations)
CREATE UNIQUE INDEX IF NOT EXISTS website_configurations_slug_uq ON website_configurations (store_slug);

-- index: website_configurations_user_uq (on website_configurations)
CREATE UNIQUE INDEX IF NOT EXISTS website_configurations_user_uq ON website_configurations (user_id);

-- index: staff_user_id_idx (on staff)
CREATE INDEX IF NOT EXISTS staff_user_id_idx ON staff (user_id);

-- index: web_orders_status_idx (on web_orders)
CREATE INDEX IF NOT EXISTS web_orders_status_idx ON web_orders (status, created_at);

-- index: web_order_items_order_idx (on web_order_items)
CREATE INDEX IF NOT EXISTS web_order_items_order_idx ON web_order_items (order_id);

-- index: product_variants_product_idx (on product_variants)
CREATE INDEX IF NOT EXISTS product_variants_product_idx
       ON product_variants (owner_user_id, product_id);

-- index: product_variants_default_uq (on product_variants)
CREATE UNIQUE INDEX IF NOT EXISTS product_variants_default_uq
       ON product_variants (product_id) WHERE is_default = 1;

-- index: product_variants_owner_sku_uq (on product_variants)
CREATE UNIQUE INDEX IF NOT EXISTS product_variants_owner_sku_uq
       ON product_variants (owner_user_id, sku) WHERE sku IS NOT NULL;

-- index: barcodes_owner_code_uq (on barcodes)
CREATE UNIQUE INDEX IF NOT EXISTS barcodes_owner_code_uq
       ON barcodes (owner_user_id, code);

-- index: barcodes_variant_idx (on barcodes)
CREATE INDEX IF NOT EXISTS barcodes_variant_idx ON barcodes (variant_id);

-- index: barcodes_unit_idx (on barcodes)
CREATE INDEX IF NOT EXISTS barcodes_unit_idx ON barcodes (unit_id);

-- index: item_labels_owner_code_uq (on item_labels)
CREATE UNIQUE INDEX IF NOT EXISTS item_labels_owner_code_uq ON item_labels (owner_user_id, code);

-- index: expense_categories_owner_name_uq (on expense_categories)
CREATE UNIQUE INDEX IF NOT EXISTS expense_categories_owner_name_uq
       ON expense_categories (owner_user_id, name COLLATE NOCASE)
       WHERE deleted_at IS NULL;

PRAGMA foreign_keys = ON;
