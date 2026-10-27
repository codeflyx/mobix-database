-- ============================================================
-- TABLE: product_variants
-- Purpose: The real stockable unit. Sits between `products` (the
--   catalogue entry) and stock, so one product can sell as
--   "Ladies / Men / Plain" or "Black·128GB / Blue·256GB" at
--   different prices, each with its own stock and barcodes.
--
-- Every product has EXACTLY ONE variant with is_default=1, created
--   automatically. A shop that never opens the variants UI is
--   unaffected — its default variant simply mirrors the product.
--   Enforced by product_variants_default_uq.
--
-- Price columns are NULLABLE and NULL means INHERIT FROM PRODUCT:
--   sale_price      NULL → products.sale_price
--   min_sale_price  NULL → products.min_sale_price
--   purchase_price  NULL → products.default_purchase_price
--   low_stock_alert NULL → products.low_stock_alert
--   A variant only stores what differs, so changing the product's
--   price still flows through to every variant that never overrode
--   it. Clearing a variant's price restores inheritance — it must
--   never be read as 0/free (see variantPriceSql() in
--   mobipos-software/lib/variants.js, which every caller shares).
--
-- track_serials is per-VARIANT, not per-product, so one product may
--   have a serialised variant and a counted one:
--     0 → stock = SUM(stock_movements.qty_delta WHERE variant_id=?)
--     1 → stock = COUNT(imei_units WHERE variant_id=? AND status='in_stock')
--   Seeded from products.stock_tracking_type during the backfill.
--
-- attrs: JSON object of the axes this variant sits on, e.g.
--   '{"color":"Black","storage":"128GB"}' or '{"style":"Ladies"}'.
--   Replaces the display-only color_options/storage_options JSON
--   arrays on `products`, which carried no price and no stock.
--
-- money: INTEGER PAISA (rupees x 100) — same as products/invoices.
-- deleted_at: soft delete — historical invoice_items reference
--   variant_id for display.
--
-- Created/backfilled by migrations/migrate_14_variants_barcodes.sql,
-- applied automatically by lib/variants.js ensureVariantsSchema().
-- ============================================================

CREATE TABLE IF NOT EXISTS product_variants (
  id              TEXT PRIMARY KEY NOT NULL,
  owner_user_id   TEXT NOT NULL REFERENCES users (id),
  product_id      TEXT NOT NULL REFERENCES products (id),

  name            TEXT NOT NULL,
  attrs           TEXT NOT NULL DEFAULT '{}',

  sku             TEXT,

  sale_price      INTEGER,
  min_sale_price  INTEGER,
  purchase_price  INTEGER,
  low_stock_alert INTEGER,

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

CREATE UNIQUE INDEX IF NOT EXISTS product_variants_default_uq
  ON product_variants (product_id) WHERE is_default = 1;

CREATE UNIQUE INDEX IF NOT EXISTS product_variants_owner_sku_uq
  ON product_variants (owner_user_id, sku) WHERE sku IS NOT NULL;
