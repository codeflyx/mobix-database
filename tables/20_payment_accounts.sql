-- ============================================================
-- TABLE: payment_accounts
-- Purpose: The CENTRAL list of money-holding accounts for a shop —
--   Cash drawer, JazzCash, EasyPaisa, Bank, and any custom wallet/bank.
--   Replaces hardcoded payment-method strings everywhere: every payment
--   dropdown (POS sale, purchase, expense, manual payment) reads this
--   table, and payment rows reference an account by id.
--
-- method_key: stable slug ('cash','jazzcash','easypaisa','bank', or a
--   custom slug). Mirrored into payments.method / expenses.payment_method
--   for display and backward compatibility. NULL = pure manual account.
-- is_system: 1 for the 4 seeded defaults — can be deactivated, not deleted.
-- balances: PKR as paisa. current_balance is maintained by a ledger in a
--   later phase (Level 2); for now it tracks opening_balance only.
-- deleted_at: soft delete.
--
-- Seeded per shop (lazily by the app): Cash, JazzCash, EasyPaisa, Bank.
-- ============================================================

CREATE TABLE IF NOT EXISTS payment_accounts (
  id              TEXT PRIMARY KEY NOT NULL,
  owner_user_id   TEXT NOT NULL REFERENCES users (id),

  method_key      TEXT,
  account_title   TEXT NOT NULL,
  account_number  TEXT,
  notes           TEXT,

  opening_balance INTEGER NOT NULL DEFAULT 0,
  current_balance INTEGER NOT NULL DEFAULT 0,

  is_system       INTEGER NOT NULL DEFAULT 0 CHECK (is_system IN (0, 1)),
  is_active       INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  sort_order      INTEGER NOT NULL DEFAULT 0,

  created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  deleted_at      TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS payment_accounts_owner_key_uq
  ON payment_accounts (owner_user_id, method_key)
  WHERE method_key IS NOT NULL AND deleted_at IS NULL;
