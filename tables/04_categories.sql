-- ============================================================
-- TABLE: categories
-- Purpose: Product categories for grouping and filtering.
-- sort_order: controls display order in UI (lower = first).
-- Name is unique per shop (owner_user_id + name).
-- ============================================================

CREATE TABLE IF NOT EXISTS categories (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),

  name          TEXT NOT NULL,
  sort_order    INTEGER NOT NULL DEFAULT 0,

  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS categories_owner_name_uq
  ON categories (owner_user_id, name);
