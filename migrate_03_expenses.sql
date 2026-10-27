-- ============================================================
-- MIGRATION: Add expenses table
-- Run this in the Turso SQL editor (one paste, one click).
-- Safe to run multiple times — idempotent.
-- Powers the /expenses page and the Profit & Loss report
-- (which already queries this table for net-profit).
-- ============================================================

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

CREATE INDEX IF NOT EXISTS expenses_owner_date_idx
  ON expenses (owner_user_id, occurred_at);
CREATE INDEX IF NOT EXISTS expenses_owner_category_idx
  ON expenses (owner_user_id, category_name);
