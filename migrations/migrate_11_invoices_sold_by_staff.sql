-- ============================================================
-- Migration 11: invoices.sold_by_staff_id
-- Adds the salesperson/employee attribution column so an owner can
-- see who made each sale (commission reporting) independently of
-- created_by (the logged-in operator, kept for audit). NULL = the
-- shop owner made the sale themself. Applied additively/idempotently
-- by mobipos-software itself (lib/db.js query path in app/pos/actions.js)
-- the next time that shop's install runs a sale — no manual run needed.
-- ============================================================

ALTER TABLE invoices ADD COLUMN sold_by_staff_id TEXT REFERENCES staff (id);

CREATE INDEX IF NOT EXISTS invoices_sold_by_staff_idx
  ON invoices (sold_by_staff_id);
