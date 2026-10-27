-- ============================================================
-- MIGRATION: Centralised payment accounts (dynamic, no hardcoded methods)
-- Run this in the Turso SQL editor.
-- Run ONCE — the payments rebuild is not meant to be re-run repeatedly.
--
-- Introduces `payment_accounts`: one row per money-holding account
-- (Cash, JazzCash, EasyPaisa, Bank, or any custom wallet/bank). Every
-- payment dropdown in both apps reads from this table instead of a
-- hardcoded list. Payments/expenses reference an account by id.
-- ============================================================

-- 1. payment_accounts — the central account list
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

CREATE UNIQUE INDEX IF NOT EXISTS payment_accounts_owner_key_uq
  ON payment_accounts (owner_user_id, method_key)
  WHERE method_key IS NOT NULL AND deleted_at IS NULL;

-- 1b. payment_account_ledger — append-only money movements per account.
--     Already referenced by the cashier app (lib/finance.js postToLedger);
--     this creates the table it expects. Powers the cash-flow view (Level 2).
CREATE TABLE IF NOT EXISTS payment_account_ledger (
  id               TEXT PRIMARY KEY NOT NULL,
  account_id       TEXT NOT NULL REFERENCES payment_accounts (id),
  owner_user_id    TEXT NOT NULL REFERENCES users (id),
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('credit', 'debit')),
  source_type      TEXT NOT NULL,   -- 'order','expense','supplier_payment','transfer_in','transfer_out','opening_balance','manual','adjustment','order_reversal'
  source_id        TEXT,
  amount           INTEGER NOT NULL,      -- paisa
  balance_before   INTEGER NOT NULL DEFAULT 0,
  balance_after    INTEGER NOT NULL DEFAULT 0,
  description      TEXT,
  notes            TEXT,
  transaction_date TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d', 'now')),
  created_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS pa_ledger_account_idx ON payment_account_ledger (account_id);
CREATE INDEX IF NOT EXISTS pa_ledger_owner_date_idx ON payment_account_ledger (owner_user_id, transaction_date);

-- 2. Rebuild `payments` to (a) drop the hardcoded method CHECK and
--    (b) add payment_account_id. SQLite cannot drop a CHECK via ALTER,
--    so we copy → drop → rename.
DROP TABLE IF EXISTS payments_new;

CREATE TABLE payments_new (
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
);

INSERT INTO payments_new
  (id, owner_user_id, direction, method, amount, invoice_id, purchase_id,
   reference_no, notes, received_by, occurred_at, created_at, deleted_at)
SELECT
   id, owner_user_id, direction, method, amount, invoice_id, purchase_id,
   reference_no, notes, received_by, occurred_at, created_at, deleted_at
FROM payments;

DROP TABLE payments;
ALTER TABLE payments_new RENAME TO payments;

CREATE INDEX IF NOT EXISTS payments_invoice_idx  ON payments (invoice_id);
CREATE INDEX IF NOT EXISTS payments_purchase_idx ON payments (purchase_id);
CREATE INDEX IF NOT EXISTS payments_account_idx  ON payments (payment_account_id);
