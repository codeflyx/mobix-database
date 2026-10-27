-- ============================================================
-- Migration 14: product_variants + barcodes
--
-- Introduces the variant layer between `products` and stock, and a
-- many-codes-to-one-target barcode table. Applied additively and
-- idempotently by the app itself (mobipos-software/lib/variants.js
-- ensureVariantsSchema()) on first touch of any page that reads
-- products/POS — no manual run needed. This file is the canonical
-- record of what that bootstrap does.
--
-- WHY
--   `products` was both the catalogue entry AND the stockable thing:
--   one price, one barcode. A shop selling "Vivo Y17 back cover" in
--   Ladies / Men / Plain at different prices had nowhere to put them —
--   products.color_options / storage_options were display-only JSON
--   with no price, no stock and nothing scannable. Same gap on phones:
--   Galaxy A15 Black-128 and Blue-256 are different prices, one row.
--
-- THE BARCODE MODEL (the part that is easy to get backwards)
--   A barcode identifies a KIND, not a THING. 100 identical covers
--   share ONE code — scanning it means "+1", and stock is a count.
--   A variant holds SEVERAL codes because the same item arrives with
--   supplier A's barcode, then supplier B's, plus the shop's own
--   printed label: three aliases, one variant. Serialised goods are
--   the opposite — kind='unit' points one code at one imei_units row,
--   because those units are not fungible.
--
-- MONEY is INTEGER PAISA (rupees x 100), matching the live data in
--   products / invoices / payments_new. (The "whole rupees" note at the
--   top of SCHEMA.md is stale — a 44,999 phone stores as 4499900.)
-- ============================================================

-- ── product_variants ────────────────────────────────────────
-- NULL price columns mean "inherit from products" — a variant only
-- stores what actually differs, so editing the product's price still
-- flows through to every variant that never overrode it.
CREATE TABLE IF NOT EXISTS product_variants (
  id              TEXT PRIMARY KEY NOT NULL,
  owner_user_id   TEXT NOT NULL REFERENCES users (id),
  product_id      TEXT NOT NULL REFERENCES products (id),

  name            TEXT NOT NULL,          -- 'Ladies' | 'Black · 128GB' | 'Default'
  attrs           TEXT NOT NULL DEFAULT '{}',  -- JSON {"color":"Black","storage":"128GB"}

  sku             TEXT,

  sale_price      INTEGER,                -- NULL → products.sale_price
  min_sale_price  INTEGER,                -- NULL → products.min_sale_price
  purchase_price  INTEGER,                -- NULL → products.default_purchase_price
  low_stock_alert INTEGER,                -- NULL → products.low_stock_alert

  -- Per-VARIANT, not per-product: one product may have a serialised
  -- variant and a counted one.
  --   0 → stock = SUM(stock_movements.qty_delta)
  --   1 → stock = COUNT(imei_units WHERE status='in_stock')
  track_serials   INTEGER NOT NULL DEFAULT 0 CHECK (track_serials IN (0,1)),

  is_default      INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0,1)),
  sort_order      INTEGER NOT NULL DEFAULT 0,
  is_active       INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),

  created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  deleted_at      TEXT
);

CREATE INDEX IF NOT EXISTS product_variants_product_idx
  ON product_variants (owner_user_id, product_id);

-- Exactly one default per product — the backfill below and
-- createVariant() both rely on this to stay idempotent.
CREATE UNIQUE INDEX IF NOT EXISTS product_variants_default_uq
  ON product_variants (product_id) WHERE is_default = 1;

CREATE UNIQUE INDEX IF NOT EXISTS product_variants_owner_sku_uq
  ON product_variants (owner_user_id, sku) WHERE sku IS NOT NULL;

-- ── barcodes ────────────────────────────────────────────────
-- Exactly one of variant_id / unit_id is set, per `kind`. The unique
-- index on (owner_user_id, code) IS the scan system: one lookup, one
-- row, no ambiguity.
CREATE TABLE IF NOT EXISTS barcodes (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),

  code          TEXT NOT NULL,
  kind          TEXT NOT NULL DEFAULT 'variant' CHECK (kind IN ('variant','unit')),

  variant_id    TEXT REFERENCES product_variants (id),
  unit_id       TEXT REFERENCES imei_units (id),

  source        TEXT NOT NULL DEFAULT 'manual'
                CHECK (source IN ('manual','supplier','printed','imported')),

  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS barcodes_owner_code_uq ON barcodes (owner_user_id, code);
CREATE INDEX IF NOT EXISTS barcodes_variant_idx ON barcodes (variant_id);
CREATE INDEX IF NOT EXISTS barcodes_unit_idx ON barcodes (unit_id);

-- ── variant_id on everything that references a product ──────
-- SQLite has no ADD COLUMN IF NOT EXISTS: each line errors harmlessly
-- ("duplicate column name") if already applied. Run them individually.
-- The app's bootstrap checks PRAGMA table_info first and skips.
ALTER TABLE product_stock         ADD COLUMN variant_id TEXT REFERENCES product_variants (id);
ALTER TABLE stock_movements       ADD COLUMN variant_id TEXT REFERENCES product_variants (id);
ALTER TABLE imei_units            ADD COLUMN variant_id TEXT REFERENCES product_variants (id);
ALTER TABLE invoice_items         ADD COLUMN variant_id TEXT REFERENCES product_variants (id);
ALTER TABLE purchase_items        ADD COLUMN variant_id TEXT REFERENCES product_variants (id);
ALTER TABLE sale_order_items      ADD COLUMN variant_id TEXT REFERENCES product_variants (id);
ALTER TABLE purchase_return_items ADD COLUMN variant_id TEXT REFERENCES product_variants (id);
ALTER TABLE web_order_items       ADD COLUMN variant_id TEXT REFERENCES product_variants (id);

-- ── Backfill 1: a default variant for every product ─────────
-- One statement, not a per-product round trip. Deliberately NOT scoped
-- to a single owner_user_id — a tenant DB may hold more than one owner
-- and a half-migrated table would break the stock reads.
INSERT INTO product_variants
  (id, owner_user_id, product_id, name, attrs, sale_price, min_sale_price,
   purchase_price, low_stock_alert, track_serials, is_default, sort_order,
   is_active, created_at, updated_at)
SELECT
  lower(hex(randomblob(16))),
  p.owner_user_id,
  p.id,
  'Default',
  '{}',
  NULL, NULL, NULL, NULL,
  CASE WHEN p.stock_tracking_type = 'imei' THEN 1 ELSE 0 END,
  1, 0, 1,
  strftime('%Y-%m-%dT%H:%M:%SZ','now'),
  strftime('%Y-%m-%dT%H:%M:%SZ','now')
FROM products p
WHERE p.deleted_at IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM product_variants v
    WHERE v.product_id = p.id AND v.is_default = 1
  );

-- ── Backfill 2: products.barcode → barcodes ─────────────────
-- OR IGNORE absorbs two products sharing one barcode (the old schema's
-- unique index covered sku only, so that was possible): first one wins
-- and the collision surfaces in the UI rather than failing the migration.
INSERT OR IGNORE INTO barcodes
  (id, owner_user_id, code, kind, variant_id, source, created_at)
SELECT
  lower(hex(randomblob(16))),
  p.owner_user_id,
  trim(p.barcode),
  'variant',
  v.id,
  'imported',
  strftime('%Y-%m-%dT%H:%M:%SZ','now')
FROM products p
JOIN product_variants v ON v.product_id = p.id AND v.is_default = 1
WHERE p.barcode IS NOT NULL
  AND trim(p.barcode) <> ''
  AND p.deleted_at IS NULL;

-- ── Backfill 3: point historical rows at the default variant ─
UPDATE product_stock SET variant_id = (
  SELECT v.id FROM product_variants v
  WHERE v.product_id = product_stock.product_id AND v.is_default = 1
) WHERE variant_id IS NULL AND product_id IS NOT NULL;

UPDATE stock_movements SET variant_id = (
  SELECT v.id FROM product_variants v
  WHERE v.product_id = stock_movements.product_id AND v.is_default = 1
) WHERE variant_id IS NULL AND product_id IS NOT NULL;

UPDATE imei_units SET variant_id = (
  SELECT v.id FROM product_variants v
  WHERE v.product_id = imei_units.product_id AND v.is_default = 1
) WHERE variant_id IS NULL AND product_id IS NOT NULL;

UPDATE invoice_items SET variant_id = (
  SELECT v.id FROM product_variants v
  WHERE v.product_id = invoice_items.product_id AND v.is_default = 1
) WHERE variant_id IS NULL AND product_id IS NOT NULL;

UPDATE purchase_items SET variant_id = (
  SELECT v.id FROM product_variants v
  WHERE v.product_id = purchase_items.product_id AND v.is_default = 1
) WHERE variant_id IS NULL AND product_id IS NOT NULL;
