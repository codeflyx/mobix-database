-- ============================================================
-- MIGRATION 02: Add missing columns to imei_units
-- Run this in the Turso SQL editor after migrate_01.
-- ALTER TABLE ADD COLUMN is idempotent in SQLite only if the
-- column doesn't exist — run each line separately if needed.
-- ============================================================

-- purchase_id: direct link to the purchase that brought this unit in
ALTER TABLE imei_units ADD COLUMN purchase_id TEXT REFERENCES purchases (id);

-- warranty_days: warranty period for this specific unit
ALTER TABLE imei_units ADD COLUMN warranty_days INTEGER NOT NULL DEFAULT 0;

-- deleted_at: soft delete (NULL = active)
ALTER TABLE imei_units ADD COLUMN deleted_at TEXT;

-- Index to speed up void-purchase lookups by purchase_id
CREATE INDEX IF NOT EXISTS imei_units_purchase_idx
  ON imei_units (purchase_id);
