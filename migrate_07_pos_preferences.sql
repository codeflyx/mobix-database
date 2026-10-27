-- ============================================================
-- MIGRATION 07: pos_preferences
-- Purpose: Per-shop POS terminal UI preferences that need to
-- persist across devices/sessions (so they live in the DB rather
-- than localStorage). One row per shop owner.
-- ============================================================

CREATE TABLE IF NOT EXISTS pos_preferences (
  owner_user_id          TEXT PRIMARY KEY NOT NULL REFERENCES users (id),

  -- Show live payment-account balances inside the payment drawer.
  show_account_balances  INTEGER NOT NULL DEFAULT 0,

  updated_at             TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
