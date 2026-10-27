-- ============================================================
-- Migration 12: pos_preferences.default_staff_id
-- The salesperson pre-selected in the POS payment drawer so the
-- cashier doesn't have to pick one on every sale. Lives in the DB
-- (not localStorage) for the same reason as show_account_balances —
-- it must survive across devices/sessions and be settable centrally.
-- Applied additively/idempotently by mobipos-software itself
-- (lib/posPreferences.js ensureTable()) on first touch — no manual
-- run needed.
-- ============================================================

ALTER TABLE pos_preferences ADD COLUMN default_staff_id TEXT REFERENCES staff (id);
