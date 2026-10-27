-- ============================================================
-- TABLE: expenses
-- Purpose: Shop operating expenses (rent, electricity, salaries,
--   tea, transport, etc.) — anything paid out that is NOT a
--   supplier purchase. Feeds the Profit & Loss report:
--     net_profit = gross_profit - SUM(expenses.amount)
-- amount: PKR stored as paisa (rupees * 100), like all money here.
-- category_name: free-text bucket, GROUP BY'd in the P&L report.
-- payment_method: which account the money left from.
-- deleted_at: soft delete — filtered out in all queries.
-- ============================================================

CREATE TABLE IF NOT EXISTS expenses (
  id               TEXT PRIMARY KEY NOT NULL,
  owner_user_id    TEXT NOT NULL REFERENCES users (id),

  -- money: PKR whole rupees stored as paisa (rupees * 100)
  amount           INTEGER NOT NULL,

  category_name    TEXT,
  subcategory_name TEXT,

  payment_method     TEXT NOT NULL DEFAULT 'cash',  -- free text: mirror of payment_accounts.method_key
  payment_account_id TEXT REFERENCES payment_accounts (id),

  vendor           TEXT,
  receipt_no       TEXT,
  notes            TEXT,

  created_by       TEXT REFERENCES users (id),

  occurred_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  deleted_at       TEXT,
  created_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS expenses_owner_date_idx
  ON expenses (owner_user_id, occurred_at);
CREATE INDEX IF NOT EXISTS expenses_owner_category_idx
  ON expenses (owner_user_id, category_name);
