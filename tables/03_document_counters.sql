-- ============================================================
-- TABLE: document_counters
-- Purpose: Generates sequential human-readable document numbers.
-- Usage:  read next_no → format as prefix+padded → INSERT doc
--         → UPDATE next_no = next_no + 1 (all in one transaction).
-- doc_type values in use:
--   'invoice'          → INV-000001
--   'purchase'         → PUR-000001
--   'return_sale'      → RSL-000001
--   'return_purchase'  → RPR-000001
--   'product'          → plain integer serial_no for products
--   'item_label'       → 11-digit numeric body (prefix '', padding 11) for
--                        item_labels.code; a GS1 (UPC-A/EAN-13 style) check
--                        digit is appended
--                        by the app, making the printed code 12 digits.
-- padding is per doc_type and set by the app from lib/documentNumbers.js:
--   invoice                          → 5  (POS-00001 … POS-99999)
--   purchase / repair / easyload /
--   adjustment / old_sale_bill       → 4  (PUR-0001 … PUR-9999)
--   item_label                       → 11 (GS1 body; do NOT change)
-- Exceeding the width is harmless — the number simply grows wider.
-- One row per (owner_user_id, doc_type).
-- ============================================================

CREATE TABLE IF NOT EXISTS document_counters (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),

  doc_type      TEXT NOT NULL,
  prefix        TEXT NOT NULL,

  next_no       INTEGER NOT NULL DEFAULT 1,
  padding       INTEGER NOT NULL DEFAULT 4,

  updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS doc_counters_owner_type_uq
  ON document_counters (owner_user_id, doc_type);
