-- ============================================================
-- Migration 13: item_labels
-- Unique-per-print barcode/QR labels for the Products -> Barcode Labels
-- page (a general-purpose label printer, not linked to any product).
-- Applied additively/idempotently by the app itself
-- (mobipos-software/lib/labels.js ensureItemLabelsTable()) the next
-- time that page is opened on each shop's install — no manual run
-- needed. Codes are reserved from document_counters (doc_type =
-- 'item_label'), which self-heals the same way on first use.
-- ============================================================

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

CREATE UNIQUE INDEX IF NOT EXISTS item_labels_owner_code_uq
  ON item_labels (owner_user_id, code);
