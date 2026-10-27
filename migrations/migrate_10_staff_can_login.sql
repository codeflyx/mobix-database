-- ============================================================
-- Migration 10: staff.can_login
-- Adds a flag so a staff row can exist purely for sale attribution
-- (commission tracking) without ever signing in to the software.
-- When 0, email/password are not required and the Employees page
-- hides the login fields. Applied additively/idempotently by the
-- app itself (mobipos-admin/lib/tenant-db.js ensureStaffTable()) the
-- next time each shop's tenant DB is touched — no manual run needed.
-- ============================================================

-- No CHECK constraint here (unlike a fresh CREATE TABLE) — kept consistent
-- with every other ADD COLUMN in this codebase; 0/1 is enforced in app code.
ALTER TABLE staff ADD COLUMN can_login INTEGER NOT NULL DEFAULT 1;
