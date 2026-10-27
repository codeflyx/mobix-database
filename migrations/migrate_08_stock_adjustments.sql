-- ============================================================
-- Migration 08: Stock Adjustments
-- Adds a header table for grouped manual stock corrections.
-- Each adjustment item writes into stock_movements with
-- reason='adjustment', ref_table='stock_adjustments', ref_id=adj.id
-- ============================================================

CREATE TABLE IF NOT EXISTS stock_adjustments (
  id             TEXT PRIMARY KEY NOT NULL,
  owner_user_id  TEXT NOT NULL REFERENCES users (id),

  adj_no         TEXT NOT NULL,

  -- Why the adjustment is being made
  reason_type    TEXT NOT NULL DEFAULT 'count_correction'
                 CHECK (reason_type IN (
                   'count_correction',
                   'damaged',
                   'found',
                   'opening_stock',
                   'write_off',
                   'transfer',
                   'other'
                 )),

  total_items    INTEGER NOT NULL DEFAULT 0,
  notes          TEXT,

  created_by     TEXT REFERENCES users (id),
  occurred_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS stock_adjustments_adj_no_uq
  ON stock_adjustments (owner_user_id, adj_no);

CREATE INDEX IF NOT EXISTS stock_adjustments_owner_idx
  ON stock_adjustments (owner_user_id, occurred_at);
