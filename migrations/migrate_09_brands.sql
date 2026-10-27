-- ============================================================
-- Migration 09: Brands
-- Adds a per-shop brand lookup table that powers the searchable
-- brand picker on the Products screens (Add Product + Quick Add).
-- A general set of brands is seeded for every shop by the app
-- (lib/brands.js → ensureDefaultBrands); users can add more.
-- products.brand keeps storing the brand NAME (text) — unchanged.
-- ============================================================

CREATE TABLE IF NOT EXISTS brands (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),

  name          TEXT NOT NULL,
  sort_order    INTEGER NOT NULL DEFAULT 0,

  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS brands_owner_name_uq
  ON brands (owner_user_id, name);
