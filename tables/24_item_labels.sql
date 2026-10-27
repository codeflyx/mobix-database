-- ============================================================
-- TABLE: item_labels
-- Purpose: One row per physical barcode/QR sticker generated and printed —
-- "pick a quantity, generate, print, cut, paste one on each item, scan at
-- POS". Deliberately NOT linked to any product: this is a general-purpose
-- label printer, not a per-product catalog tool. Every code is globally
-- unique per shop.
--
-- code: 12-digit numeric string — an 11-digit sequential body (from
--   document_counters, doc_type='item_label') plus a trailing GS1 (the
--   UPC-A/EAN-13 checksum algorithm) check digit. Kept short and numeric
--   only (not a UUID/alphanumeric id) so a Code 128 rendering of it stays
--   dense enough to scan reliably on cheap laser scanners even on a small
--   (~40mm) label — this is the same length convention as UPC-A.
-- title: optional free text printed on the label under the code (e.g. a
--   shop name or batch note) — same title for every label in one
--   generation run, not tied to any specific item.
-- symbology: which format was actually printed — purely informational,
--   the code itself doesn't change.
-- printed_at: set the moment the label PDF is generated (this app has no
--   way to confirm an actual physical print completed), so it really
--   means "included in a generated label sheet at least once".
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
