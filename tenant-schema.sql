-- database/tenant-schema.sql
--
-- The canonical schema for ONE SHOP's database.
--
-- Captured 2026-10-24 from the live tenant databases, as the union of every
-- table any shop had. It exists because provisioning used to copy DDL out of
-- the CONTROL database's sqlite_master, which only ever held the original
-- table set: tables added later are created lazily inside tenant databases
-- (lib/people.js, lib/variants.js, lib/labels.js, lib/expenses.js,
-- lib/web-orders.js), so they never reached the template. A freshly
-- provisioned shop came up with 41 of 62 tables, and sync-tenant-schemas
-- could not repair it because it read the same stale source.
--
-- Control-plane tables (user_databases, super_admins,
-- website_configurations) are deliberately excluded: they belong to the
-- control database, never to a shop. `users` IS included — see the note on
-- that table; a copy of the owner's row lives in every shop so the till
-- works offline.
--
-- Every statement is idempotent, so this can be re-applied to an existing
-- shop to add whatever it is missing.
--
-- When a feature adds a table, add it here too, or new shops will not get it.

-- The shop owner's own account, COPIED into the shop's database at
-- provisioning (turso-platform.js -> copyTableRows(tenantClient, "users", …)).
-- It belongs here, unlike the other control-plane tables: the till reads it
-- with no internet to name the shop and to sign the owner in offline
-- (software/lib/auth.js, lib/shopIdentity.js), and nearly every table in this
-- file carries owner_user_id REFERENCES users (id).
--
-- user_databases, super_admins and website_configurations are NOT here: those
-- live only in the control database and a shop must never hold them.
CREATE TABLE IF NOT EXISTS users (
  id               TEXT PRIMARY KEY NOT NULL,
  full_name        TEXT NOT NULL,
  username         TEXT NOT NULL,
  password         TEXT NOT NULL,
  role             TEXT NOT NULL DEFAULT 'admin'
                     CHECK (role IN ('admin', 'cashier')),
  phone            TEXT,
  email            TEXT,
  is_active        INTEGER NOT NULL DEFAULT 1
                     CHECK (is_active IN (0, 1)),
  parent_admin_id  TEXT,
  staff_role       TEXT,
  permissions      TEXT,
  created_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS attendance_holidays (
      id            TEXT PRIMARY KEY NOT NULL,
      owner_user_id TEXT NOT NULL,
      holiday_date  TEXT NOT NULL,
      name          TEXT NOT NULL,
      is_paid       INTEGER NOT NULL DEFAULT 1 CHECK (is_paid IN (0,1)),
      created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

CREATE TABLE IF NOT EXISTS attendance_policy (
      owner_user_id          TEXT PRIMARY KEY NOT NULL,
      work_start             TEXT NOT NULL DEFAULT '10:00',
      work_end               TEXT NOT NULL DEFAULT '22:00',
      grace_minutes          INTEGER NOT NULL DEFAULT 15,
      half_day_after_minutes INTEGER NOT NULL DEFAULT 120,
      -- Comma-separated day numbers, 0 = Sunday. '0' means Sundays off.
      weekly_offs            TEXT NOT NULL DEFAULT '0',
      updated_at             TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

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

CREATE TABLE IF NOT EXISTS brands (
      id            TEXT PRIMARY KEY NOT NULL,
      owner_user_id TEXT NOT NULL REFERENCES users (id),
      name          TEXT NOT NULL,
      sort_order    INTEGER NOT NULL DEFAULT 0,
      created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
      updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
    );

CREATE TABLE IF NOT EXISTS categories (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),
  name          TEXT NOT NULL,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS customer_documents (
  id             TEXT PRIMARY KEY NOT NULL,
  customer_id    TEXT NOT NULL REFERENCES customers (id),
  document_type  TEXT NOT NULL,
  file_url       TEXT NOT NULL,
  notes          TEXT,
  created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

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
, email TEXT
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

CREATE TABLE IF NOT EXISTS employee_attendance (
      id                    TEXT PRIMARY KEY NOT NULL,
      owner_user_id         TEXT NOT NULL,
      employee_id           TEXT NOT NULL REFERENCES employees (id),
      employee_name_at_entry TEXT,

      work_date             TEXT NOT NULL,          -- 'YYYY-MM-DD', the shop's day
      check_in_at           TEXT,                   -- UTC ISO
      check_out_at          TEXT,
      status                TEXT NOT NULL DEFAULT 'present'
                              CHECK (status IN ('present','absent','late','half_day',
                                                'leave','holiday','weekly_off')),
      minutes_worked        INTEGER NOT NULL DEFAULT 0,
      minutes_late          INTEGER NOT NULL DEFAULT 0,
      -- 'manual' today; 'fingerprint' once a reader is wired up.
      source                TEXT NOT NULL DEFAULT 'manual'
                              CHECK (source IN ('manual','fingerprint','import')),
      notes                 TEXT,
      created_by            TEXT,
      created_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

CREATE TABLE IF NOT EXISTS employee_attendance_rules (
      id                  TEXT PRIMARY KEY NOT NULL,
      owner_user_id       TEXT NOT NULL,
      employee_id         TEXT NOT NULL REFERENCES employees (id),
      work_start          TEXT,
      work_end            TEXT,
      grace_minutes       INTEGER,
      weekly_offs         TEXT,
      -- Days before this are not counted as absences, so hiring someone
      -- mid-month doesn't open with a wall of absent days.
      tracking_start_date TEXT,
      created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

CREATE TABLE IF NOT EXISTS employee_departments (
      id            TEXT PRIMARY KEY NOT NULL,
      owner_user_id TEXT NOT NULL,
      name          TEXT NOT NULL,
      description   TEXT,
      is_active     INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
      created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      deleted_at    TEXT
    );

CREATE TABLE IF NOT EXISTS employee_fingerprints (
      id              TEXT PRIMARY KEY NOT NULL,
      owner_user_id   TEXT NOT NULL,
      employee_id     TEXT NOT NULL REFERENCES employees (id),
      finger_label    TEXT,                    -- 'right_thumb', 'left_index', …
      template        TEXT NOT NULL,           -- base64 template from the reader
      template_format TEXT,                    -- which reader/SDK produced it
      device_id       TEXT,                    -- where it was enrolled
      enrolled_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      is_active       INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
      created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

CREATE TABLE IF NOT EXISTS employee_leaves (
      id            TEXT PRIMARY KEY NOT NULL,
      owner_user_id TEXT NOT NULL,
      employee_id   TEXT NOT NULL REFERENCES employees (id),
      from_date     TEXT NOT NULL,
      to_date       TEXT NOT NULL,
      leave_type    TEXT NOT NULL DEFAULT 'unpaid'
                      CHECK (leave_type IN ('paid','unpaid','sick','annual')),
      reason        TEXT,
      status        TEXT NOT NULL DEFAULT 'approved'
                      CHECK (status IN ('pending','approved','rejected')),
      created_by    TEXT,
      created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

CREATE TABLE IF NOT EXISTS employees (
      id                 TEXT PRIMARY KEY NOT NULL,
      owner_user_id      TEXT NOT NULL,

      full_name          TEXT NOT NULL,
      phone              TEXT,
      email              TEXT,
      cnic               TEXT,
      -- A free-text job title (Cashier, Salesman, Technician, Helper). This is
      -- NOT an auth role: what someone may DO in the app comes from their
      -- staff_accounts row and its permission grants, never from this string.
      designation        TEXT,
      department_id      TEXT REFERENCES employee_departments (id),
      joining_date       TEXT,

      -- Payroll
      salary_type        TEXT NOT NULL DEFAULT 'monthly'
                           CHECK (salary_type IN ('monthly','daily','hourly')),
      base_salary        INTEGER NOT NULL DEFAULT 0,   -- PAISA
      payment_frequency  TEXT NOT NULL DEFAULT 'monthly'
                           CHECK (payment_frequency IN ('monthly','biweekly','weekly')),

      -- Sales commission. commission_rate is BASIS POINTS for the percent
      -- types (200 = 2.00%) and PAISA for fixed_per_item.
      commission_type    TEXT NOT NULL DEFAULT 'none'
                           CHECK (commission_type IN
                             ('none','percent_of_sale','percent_of_profit','fixed_per_item')),
      commission_rate    INTEGER NOT NULL DEFAULT 0,

      is_active          INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
      notes              TEXT,

      created_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      deleted_at         TEXT
    , is_salesperson INTEGER NOT NULL DEFAULT 0);

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

CREATE TABLE IF NOT EXISTS fingerprint_scan_log (
      id               TEXT PRIMARY KEY NOT NULL,
      owner_user_id    TEXT NOT NULL,
      employee_id      TEXT REFERENCES employees (id),
      person_name      TEXT,
      person_subtitle  TEXT,
      scanned_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      device_id        TEXT,
      outcome          TEXT NOT NULL DEFAULT 'matched'
                         CHECK (outcome IN ('matched','unknown_finger','reader_error',
                                            'outside_hours','duplicate_tap','save_failed')),
      detail           TEXT,
      created_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

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
, variant_id TEXT REFERENCES product_variants (id)
-- Frozen at the sale: changing an employee's commission rate must never
-- rewrite commission already earned.
, commission_rate_at_sale INTEGER NOT NULL DEFAULT 0
, commission_amount INTEGER NOT NULL DEFAULT 0);

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
                       CHECK (status IN ('completed', 'partial', 'pending', 'cancelled', 'void')),
  void_reason          TEXT,
  notes                TEXT,
  created_by           TEXT REFERENCES users (id),
  occurred_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  created_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  deleted_at           TEXT
, sold_by_staff_id TEXT REFERENCES employees (id)
-- Captured at the sale, not joined: an employee who leaves, or is renamed,
-- must still read correctly on last month's invoices.
, sold_by_name TEXT);

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

CREATE TABLE IF NOT EXISTS payroll_advances (
      id                 TEXT PRIMARY KEY NOT NULL,
      owner_user_id      TEXT NOT NULL,
      employee_id        TEXT NOT NULL REFERENCES employees (id),
      amount             INTEGER NOT NULL DEFAULT 0,   -- PAISA
      advance_date       TEXT NOT NULL,
      payment_account_id TEXT,                         -- which account paid it out
      notes              TEXT,
      status             TEXT NOT NULL DEFAULT 'outstanding'
                           CHECK (status IN ('outstanding','settled','cancelled')),
      settled_in_run_id  TEXT,
      created_by         TEXT,
      created_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

CREATE TABLE IF NOT EXISTS payroll_employee_components (
      id            TEXT PRIMARY KEY NOT NULL,
      owner_user_id TEXT NOT NULL,
      employee_id   TEXT NOT NULL REFERENCES employees (id),
      component_id  TEXT NOT NULL REFERENCES payroll_salary_components (id),
      amount        INTEGER NOT NULL DEFAULT 0,   -- overrides default_amount
      is_active     INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
      created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

CREATE TABLE IF NOT EXISTS payroll_ledger (
      id              TEXT PRIMARY KEY NOT NULL,
      owner_user_id   TEXT NOT NULL,
      employee_id     TEXT NOT NULL REFERENCES employees (id),
      entry_date      TEXT NOT NULL,
      kind            TEXT NOT NULL CHECK (kind IN ('advance','salary','commission','adjustment')),
      amount          INTEGER NOT NULL DEFAULT 0,   -- PAISA, signed
      reference_table TEXT,
      reference_id    TEXT,
      notes           TEXT,
      created_by      TEXT,
      created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

CREATE TABLE IF NOT EXISTS payroll_run_item_adjustments (
      id            TEXT PRIMARY KEY NOT NULL,
      owner_user_id TEXT NOT NULL,
      run_item_id   TEXT NOT NULL REFERENCES payroll_run_items (id),
      label         TEXT NOT NULL,
      kind          TEXT NOT NULL CHECK (kind IN ('allowance','deduction')),
      amount        INTEGER NOT NULL DEFAULT 0,
      notes         TEXT,
      created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

CREATE TABLE IF NOT EXISTS payroll_run_items (
      id                  TEXT PRIMARY KEY NOT NULL,
      owner_user_id       TEXT NOT NULL,
      run_id              TEXT NOT NULL REFERENCES payroll_runs (id),
      employee_id         TEXT NOT NULL REFERENCES employees (id),
      employee_name_at_run TEXT NOT NULL,
      designation_at_run  TEXT,

      base_salary         INTEGER NOT NULL DEFAULT 0,
      days_in_period      INTEGER NOT NULL DEFAULT 0,
      days_present        INTEGER NOT NULL DEFAULT 0,
      days_absent         INTEGER NOT NULL DEFAULT 0,
      days_leave          INTEGER NOT NULL DEFAULT 0,

      earned_salary       INTEGER NOT NULL DEFAULT 0,
      allowances_total    INTEGER NOT NULL DEFAULT 0,
      deductions_total    INTEGER NOT NULL DEFAULT 0,
      commission_total    INTEGER NOT NULL DEFAULT 0,
      advances_deducted   INTEGER NOT NULL DEFAULT 0,
      net_pay             INTEGER NOT NULL DEFAULT 0,

      notes               TEXT,
      created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

CREATE TABLE IF NOT EXISTS payroll_runs (
      id            TEXT PRIMARY KEY NOT NULL,
      owner_user_id TEXT NOT NULL,
      run_no        TEXT NOT NULL,
      period_start  TEXT NOT NULL,
      period_end    TEXT NOT NULL,
      status        TEXT NOT NULL DEFAULT 'draft'
                      CHECK (status IN ('draft','approved','paid','cancelled')),
      total_gross   INTEGER NOT NULL DEFAULT 0,
      total_net     INTEGER NOT NULL DEFAULT 0,
      notes         TEXT,
      created_by    TEXT,
      approved_at   TEXT,
      paid_at       TEXT,
      created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

CREATE TABLE IF NOT EXISTS payroll_salary_components (
      id             TEXT PRIMARY KEY NOT NULL,
      owner_user_id  TEXT NOT NULL,
      name           TEXT NOT NULL,
      component_type TEXT NOT NULL CHECK (component_type IN ('allowance','deduction')),
      amount_type    TEXT NOT NULL DEFAULT 'fixed' CHECK (amount_type IN ('fixed','percent')),
      default_amount INTEGER NOT NULL DEFAULT 0,  -- PAISA, or BASIS POINTS when percent
      description    TEXT,
      is_active      INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
      created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      deleted_at     TEXT
    );

CREATE TABLE IF NOT EXISTS payroll_settings (
      owner_user_id      TEXT PRIMARY KEY NOT NULL,
      period_start_day   INTEGER NOT NULL DEFAULT 1,
      default_salary_type TEXT NOT NULL DEFAULT 'monthly',
      run_prefix         TEXT NOT NULL DEFAULT 'PAY',
      updated_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

CREATE TABLE IF NOT EXISTS pos_preferences (
       owner_user_id          TEXT PRIMARY KEY NOT NULL REFERENCES users (id),
       show_account_balances  INTEGER NOT NULL DEFAULT 0,
       updated_at             TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
     , default_staff_id TEXT REFERENCES employees (id), block_negative_stock INTEGER NOT NULL DEFAULT 0
     -- 'all' | 'imei' | 'quantity' | 'never' — see PO_SCAN_TRAY_MODES.
     , po_scan_tray TEXT NOT NULL DEFAULT 'all'
     , show_stock_on_pos INTEGER NOT NULL DEFAULT 1);

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
, sale_price INTEGER DEFAULT 0, is_mobile INTEGER DEFAULT 0, imei TEXT, ram TEXT, rom TEXT, color TEXT, variant_id TEXT REFERENCES product_variants (id)
-- JSON array of IMEIs scanned onto this line before the delivery arrived.
, pending_serials TEXT);

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

CREATE TABLE IF NOT EXISTS purchase_return_items (
      id             TEXT PRIMARY KEY,
      owner_user_id  TEXT NOT NULL,
      return_id      TEXT NOT NULL,
      product_id     TEXT NOT NULL,
      qty            INTEGER NOT NULL DEFAULT 0,
      unit_cost      INTEGER NOT NULL DEFAULT 0,
      return_value   INTEGER NOT NULL DEFAULT 0
    , variant_id TEXT REFERENCES product_variants (id));

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
, supplier_invoice_ref   TEXT, expected_delivery_date TEXT, currency               TEXT DEFAULT 'PKR', exchange_rate          REAL DEFAULT 1, approval_status TEXT DEFAULT 'draft', approval_by     TEXT, approval_at     TEXT, approval_notes  TEXT, images TEXT NOT NULL DEFAULT '[]'
-- Set when the delivery is actually received and its stock posted; NULL until
-- then. See lib/purchaseLifecycle.js, which also adds this to older shops.
, received_at TEXT);

CREATE TABLE IF NOT EXISTS receipt_settings (
  id                  TEXT PRIMARY KEY NOT NULL,
  owner_user_id       TEXT NOT NULL UNIQUE REFERENCES users (id),

  -- Business identity: OVERRIDES, not the source of truth.
  -- The shop's name, phone, email, address and footer live in
  -- shop_settings (Settings -> Store) and are what receipts print.
  -- A value here is an exception for the receipt only -- a trading name
  -- that differs from the registered one, a counter phone rather than the
  -- owner's mobile. NULL means inherit, which is the normal case.
  -- Resolved by lib/printing/receiptSettings.js -> RECEIPT_INHERITS.
  store_name_override   TEXT,
  phone_override        TEXT,
  email_override        TEXT,
  address_override      TEXT,
  footer_note_override  TEXT,

  -- Receipt-only text: these have no equivalent in shop_settings, so they are
  -- the source of truth for themselves. phone2 is a second number printed
  -- beside the first (a WhatsApp line, say), not an override of anything.
  phone2                TEXT,
  tagline_text          TEXT,
  thankyou_text         TEXT,
  branding_text         TEXT,

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

CREATE TABLE IF NOT EXISTS search_logs (
      id            TEXT PRIMARY KEY NOT NULL,
      owner_user_id TEXT NOT NULL,

      actor_id      TEXT,
      actor_role    TEXT,
      actor_name    TEXT,

      source        TEXT NOT NULL DEFAULT 'palette',
      query         TEXT NOT NULL,
      query_length  INTEGER NOT NULL DEFAULT 0,
      result_count  INTEGER NOT NULL DEFAULT 0,

      picked        INTEGER NOT NULL DEFAULT 0 CHECK (picked IN (0, 1)),
      picked_title  TEXT,
      picked_href   TEXT,
      picked_type   TEXT,
      picked_rank   INTEGER,

      app_source    TEXT,
      user_agent    TEXT,
      created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
    );

CREATE TABLE IF NOT EXISTS shop_settings (
  id                   TEXT PRIMARY KEY NOT NULL,
  owner_user_id        TEXT NOT NULL REFERENCES users (id),
  shop_name            TEXT NOT NULL,
  owner_name           TEXT NOT NULL,
  phone                TEXT,
  email                TEXT,
  address              TEXT,
  currency_code        TEXT NOT NULL DEFAULT 'PKR',
  invoice_prefix       TEXT NOT NULL DEFAULT 'INV',
  purchase_prefix      TEXT NOT NULL DEFAULT 'PUR',
  receipt_footer_text  TEXT,
  -- JSON: { purpose: "text with {tokens}" }. Only the purposes the owner has
  -- actually edited; the rest fall back to WA_DEFAULTS in lib/whatsapp.js.
  whatsapp_templates   TEXT,
  -- JSON blob of the shop's marketing preferences; self-healed by
  -- lib/marketingSettings.js, so it lives here too or a freshly provisioned
  -- shop only gets it if that self-heal happens to fire first.
  marketing_settings   TEXT,
  created_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

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
        is_active    INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
        updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
      , can_login INTEGER NOT NULL DEFAULT 1);

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

CREATE TABLE IF NOT EXISTS supplier_documents (
  id             TEXT PRIMARY KEY NOT NULL,
  supplier_id    TEXT NOT NULL REFERENCES suppliers (id),
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
, alternate_phone TEXT
, email TEXT
, payment_terms TEXT
);

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
      -- The invoice this order was finally rung up under, so a web order can
      -- be reconciled against the till and a double ring-up noticed.
      invoice_no        TEXT,

      created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

-- table: qist_plans
-- Instalment sales. See mobipos-software/lib/qist.js.
CREATE TABLE IF NOT EXISTS qist_plans (
      id                TEXT PRIMARY KEY NOT NULL,
      owner_user_id     TEXT NOT NULL REFERENCES users (id),
      plan_no           TEXT NOT NULL,

      customer_id       TEXT NOT NULL REFERENCES customers (id),
      invoice_id        TEXT REFERENCES invoices (id),

      item_label        TEXT NOT NULL,
      product_id        TEXT REFERENCES products (id),
      imei              TEXT,

      cash_price        INTEGER NOT NULL DEFAULT 0,
      total_price       INTEGER NOT NULL,
      advance           INTEGER NOT NULL DEFAULT 0,

      months            INTEGER NOT NULL,
      monthly_amount    INTEGER NOT NULL,
      start_date        TEXT NOT NULL,

      status            TEXT NOT NULL DEFAULT 'active',

      guarantor_name    TEXT,
      guarantor_phone   TEXT,
      notes             TEXT,

      created_by        TEXT REFERENCES users (id),
      occurred_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      deleted_at        TEXT,
      created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

-- table: qist_installments
-- One row per instalment, written out in full when the plan is created.
CREATE TABLE IF NOT EXISTS qist_installments (
      id            TEXT PRIMARY KEY NOT NULL,
      owner_user_id TEXT NOT NULL REFERENCES users (id),
      plan_id       TEXT NOT NULL REFERENCES qist_plans (id),

      seq           INTEGER NOT NULL,
      due_date      TEXT NOT NULL,
      amount        INTEGER NOT NULL,
      paid_amount   INTEGER NOT NULL DEFAULT 0,
      paid_at       TEXT,

      created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

-- table: marketing_campaigns
-- One bulk WhatsApp campaign. See mobipos-software/lib/marketingSchema.js.
CREATE TABLE IF NOT EXISTS marketing_campaigns (
      id             TEXT PRIMARY KEY NOT NULL,
      owner_user_id  TEXT NOT NULL REFERENCES users (id),

      name           TEXT NOT NULL,
      message        TEXT NOT NULL,

      status         TEXT NOT NULL DEFAULT 'running',

      total          INTEGER NOT NULL DEFAULT 0,
      sent           INTEGER NOT NULL DEFAULT 0,
      failed         INTEGER NOT NULL DEFAULT 0,
      skipped        INTEGER NOT NULL DEFAULT 0,

      started_at     TEXT,
      finished_at    TEXT,

      created_by     TEXT REFERENCES users (id),
      deleted_at     TEXT,
      created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

-- table: marketing_recipients
-- One row per person in a campaign. Doubles as the contact history every
-- later campaign reads to answer "who have we not reached yet".
CREATE TABLE IF NOT EXISTS marketing_recipients (
      id             TEXT PRIMARY KEY NOT NULL,
      owner_user_id  TEXT NOT NULL REFERENCES users (id),
      campaign_id    TEXT NOT NULL REFERENCES marketing_campaigns (id),

      customer_id    TEXT REFERENCES customers (id),
      name           TEXT,
      phone          TEXT,

      status         TEXT NOT NULL DEFAULT 'pending',
      message_sent   TEXT,
      error_message  TEXT,
      skip_reason    TEXT,

      sent_at        TEXT,
      created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

-- table: marketing_contacts
-- The Do Not Message list. Campaigns only - a customer who opts out still
-- gets their own bills and repair updates.
CREATE TABLE IF NOT EXISTS marketing_contacts (
      id             TEXT PRIMARY KEY NOT NULL,
      owner_user_id  TEXT NOT NULL REFERENCES users (id),
      customer_id    TEXT NOT NULL REFERENCES customers (id),

      opted_out      INTEGER NOT NULL DEFAULT 0,
      reason         TEXT,
      opted_out_at   TEXT,

      created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      updated_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

-- table: whatsapp_auto_log
-- What the automations sent without being asked, including what they could
-- not send. See mobipos-software/lib/whatsappAuto.js.
CREATE TABLE IF NOT EXISTS whatsapp_auto_log (
      id             TEXT PRIMARY KEY NOT NULL,
      owner_user_id  TEXT NOT NULL REFERENCES users (id),

      trigger_key    TEXT NOT NULL,
      source         TEXT NOT NULL DEFAULT 'auto',
      via            TEXT,
      customer_id    TEXT REFERENCES customers (id),
      name           TEXT,
      phone          TEXT,

      status         TEXT NOT NULL,
      message_sent   TEXT,
      error_message  TEXT,
      skip_reason    TEXT,

      occurred_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
      created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

-- ── Indexes ──────────────────────────────────────────────────────────────

CREATE UNIQUE INDEX IF NOT EXISTS users_username_uq ON users (username);
CREATE INDEX IF NOT EXISTS users_parent_admin_idx ON users (parent_admin_id);
CREATE UNIQUE INDEX IF NOT EXISTS attendance_holidays_owner_date_uq ON attendance_holidays (owner_user_id, holiday_date);
CREATE UNIQUE INDEX IF NOT EXISTS barcodes_owner_code_uq
       ON barcodes (owner_user_id, code);
CREATE INDEX IF NOT EXISTS barcodes_unit_idx ON barcodes (unit_id);
CREATE INDEX IF NOT EXISTS barcodes_variant_idx ON barcodes (variant_id);
CREATE UNIQUE INDEX IF NOT EXISTS brands_owner_name_uq ON brands (owner_user_id, name);
CREATE UNIQUE INDEX IF NOT EXISTS categories_owner_name_uq
  ON categories (owner_user_id, name);
CREATE INDEX IF NOT EXISTS customers_owner_phone_idx
  ON customers (owner_user_id, phone);
CREATE UNIQUE INDEX IF NOT EXISTS doc_counters_owner_type_uq
  ON document_counters (owner_user_id, doc_type);
CREATE UNIQUE INDEX IF NOT EXISTS employee_attendance_day_uq ON employee_attendance (employee_id, work_date);
CREATE INDEX IF NOT EXISTS employee_attendance_owner_date_idx ON employee_attendance (owner_user_id, work_date);
CREATE UNIQUE INDEX IF NOT EXISTS employee_attendance_rules_emp_uq ON employee_attendance_rules (employee_id);
CREATE UNIQUE INDEX IF NOT EXISTS employee_departments_owner_name_uq ON employee_departments (owner_user_id, name);
CREATE INDEX IF NOT EXISTS employee_fingerprints_emp_idx ON employee_fingerprints (employee_id, is_active);
CREATE INDEX IF NOT EXISTS employee_leaves_emp_idx ON employee_leaves (employee_id, from_date);
CREATE INDEX IF NOT EXISTS employees_dept_idx ON employees (department_id);
CREATE INDEX IF NOT EXISTS employees_owner_idx ON employees (owner_user_id, is_active);
CREATE UNIQUE INDEX IF NOT EXISTS expense_categories_owner_name_uq
       ON expense_categories (owner_user_id, name COLLATE NOCASE)
       WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS expenses_owner_category_idx
  ON expenses (owner_user_id, category_name);
CREATE INDEX IF NOT EXISTS expenses_owner_date_idx
  ON expenses (owner_user_id, occurred_at);
CREATE INDEX IF NOT EXISTS fingerprint_scan_log_owner_time_idx ON fingerprint_scan_log (owner_user_id, scanned_at);
-- A party's balance is SUM(amount) over their ledger rows, and that sum is
-- read on every row of the Customers and Suppliers lists, on the dashboard
-- and in the Adjust dialog. Without these it is a full table scan each
-- time, on the one table that grows with every sale, payment and
-- adjustment the shop ever makes.
CREATE INDEX IF NOT EXISTS ledger_entries_owner_customer_idx
  ON ledger_entries (owner_user_id, customer_id);
CREATE INDEX IF NOT EXISTS ledger_entries_owner_supplier_idx
  ON ledger_entries (owner_user_id, supplier_id);
CREATE INDEX IF NOT EXISTS idx_easyloads_customer ON easyloads (customer_id);
CREATE INDEX IF NOT EXISTS idx_easyloads_owner_created
     ON easyloads (owner_user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_easyloads_owner_status
     ON easyloads (owner_user_id, status);
CREATE INDEX IF NOT EXISTS idx_old_sale_bill_items_bill ON old_sale_bill_items (bill_id);
CREATE INDEX IF NOT EXISTS idx_old_sale_bills_customer ON old_sale_bills (customer_id);
CREATE INDEX IF NOT EXISTS idx_old_sale_bills_owner_created
     ON old_sale_bills (owner_user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_repair_items_repair ON repair_items (repair_id);
CREATE INDEX IF NOT EXISTS idx_repairs_customer ON repairs (customer_id);
CREATE INDEX IF NOT EXISTS idx_repairs_owner_created
     ON repairs (owner_user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_repairs_owner_status
     ON repairs (owner_user_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS imei_units_owner_imei_uq
  ON imei_units (owner_user_id, imei);
CREATE INDEX IF NOT EXISTS imei_units_product_status_idx
  ON imei_units (product_id, status);
CREATE INDEX IF NOT EXISTS imei_units_purchase_idx
  ON imei_units (purchase_id);
CREATE INDEX IF NOT EXISTS invoice_items_invoice_idx
  ON invoice_items (invoice_id);
CREATE INDEX IF NOT EXISTS invoice_items_warranty_idx
  ON invoice_items (warranty_expiry_date)
  WHERE warranty_expiry_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS invoices_customer_idx
  ON invoices (customer_id);
CREATE UNIQUE INDEX IF NOT EXISTS invoices_owner_no_uq
  ON invoices (owner_user_id, invoice_no);
CREATE UNIQUE INDEX IF NOT EXISTS item_labels_owner_code_uq ON item_labels (owner_user_id, code);
CREATE UNIQUE INDEX IF NOT EXISTS payment_accounts_owner_key_uq
  ON payment_accounts (owner_user_id, method_key)
  WHERE method_key IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS payroll_advances_emp_idx ON payroll_advances (employee_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS payroll_employee_components_uq ON payroll_employee_components (employee_id, component_id);
CREATE INDEX IF NOT EXISTS payroll_ledger_emp_idx ON payroll_ledger (employee_id, entry_date);
CREATE INDEX IF NOT EXISTS payroll_run_item_adjustments_item_idx ON payroll_run_item_adjustments (run_item_id);
CREATE UNIQUE INDEX IF NOT EXISTS payroll_run_items_uq ON payroll_run_items (run_id, employee_id);
CREATE UNIQUE INDEX IF NOT EXISTS payroll_runs_owner_no_uq ON payroll_runs (owner_user_id, run_no);
CREATE INDEX IF NOT EXISTS printers_owner_idx ON printers (owner_user_id);
CREATE UNIQUE INDEX IF NOT EXISTS product_variants_default_uq
       ON product_variants (product_id) WHERE is_default = 1;
CREATE UNIQUE INDEX IF NOT EXISTS product_variants_owner_sku_uq
       ON product_variants (owner_user_id, sku) WHERE sku IS NOT NULL;
CREATE INDEX IF NOT EXISTS product_variants_product_idx
       ON product_variants (owner_user_id, product_id);
CREATE UNIQUE INDEX IF NOT EXISTS products_owner_serial_uq
  ON products (owner_user_id, serial_no);
CREATE UNIQUE INDEX IF NOT EXISTS products_owner_sku_uq
  ON products (owner_user_id, sku)
  WHERE sku IS NOT NULL;
CREATE INDEX IF NOT EXISTS purchase_items_purchase_idx
  ON purchase_items (purchase_id);
CREATE UNIQUE INDEX IF NOT EXISTS purchases_owner_no_uq
  ON purchases (owner_user_id, purchase_no);
CREATE INDEX IF NOT EXISTS search_logs_owner_created_idx ON search_logs (owner_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS search_logs_owner_query_idx ON search_logs (owner_user_id, lower (QUERY));
CREATE INDEX IF NOT EXISTS search_logs_unpicked_idx ON search_logs (owner_user_id, created_at DESC) WHERE picked = 0;
CREATE INDEX IF NOT EXISTS staff_user_id_idx ON staff (user_id);
CREATE UNIQUE INDEX IF NOT EXISTS stock_adjustments_adj_no_uq
  ON stock_adjustments (owner_user_id, adj_no);
CREATE INDEX IF NOT EXISTS stock_adjustments_owner_idx
  ON stock_adjustments (owner_user_id, occurred_at);
CREATE INDEX IF NOT EXISTS stock_movements_product_idx
  ON stock_movements (owner_user_id, product_id);
CREATE INDEX IF NOT EXISTS web_order_items_order_idx ON web_order_items (order_id);
CREATE INDEX IF NOT EXISTS web_orders_status_idx ON web_orders (status, created_at);
CREATE INDEX IF NOT EXISTS qist_plans_owner_status_idx ON qist_plans (owner_user_id, status);
CREATE INDEX IF NOT EXISTS qist_inst_plan_idx ON qist_installments (plan_id, seq);
CREATE INDEX IF NOT EXISTS qist_inst_owner_due_idx ON qist_installments (owner_user_id, due_date);
CREATE INDEX IF NOT EXISTS marketing_campaigns_owner_idx ON marketing_campaigns (owner_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS marketing_recipients_campaign_idx ON marketing_recipients (campaign_id, status);
CREATE INDEX IF NOT EXISTS marketing_recipients_customer_idx ON marketing_recipients (owner_user_id, customer_id, sent_at);
CREATE UNIQUE INDEX IF NOT EXISTS marketing_contacts_customer_idx ON marketing_contacts (owner_user_id, customer_id);
CREATE INDEX IF NOT EXISTS whatsapp_auto_log_owner_idx ON whatsapp_auto_log (owner_user_id, occurred_at DESC);
