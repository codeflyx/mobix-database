-- ============================================================
-- TABLE: brands
-- Purpose: Product brands (manufacturers / makes) for grouping
-- and filtering — e.g. Samsung, Apple, Xiaomi.
-- A general set is seeded for every new shop; the user can add
-- their own. Name is unique per shop (owner_user_id + name).
-- products.brand stores the brand NAME (text) — this table is the
-- per-shop lookup that powers the searchable picker.
-- sort_order: controls display order in UI (lower = first).
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
