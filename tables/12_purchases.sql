-- ============================================================
-- TABLE: purchases
-- Purpose: Records stock coming IN to the shop.
-- kind:
--   'supplier'  → buying from a supplier (supplier_id set)
--   'trade_in'  → buying a used device from a customer (customer_id set)
-- type:
--   'purchase'  → normal stock purchase
--   'return'    → returning stock back (original_purchase_id set)
-- paid_total: sum of linked payments WHERE direction = 'out'.
--   Derived at query time or kept in sync by the app.
-- status:
--   'completed' → fully received and paid
--   'partial'   → received but not fully paid
--   'pending'   → ordered, not yet received
--   'cancelled' → voided
-- ============================================================

CREATE TABLE IF NOT EXISTS purchases (
  id                   TEXT PRIMARY KEY NOT NULL,
  owner_user_id        TEXT NOT NULL REFERENCES users (id),

  purchase_no          TEXT NOT NULL,

  kind                 TEXT NOT NULL DEFAULT 'supplier'
                       CHECK (kind IN ('supplier', 'trade_in')),

  type                 TEXT NOT NULL DEFAULT 'purchase'
                       CHECK (type IN ('purchase', 'return')),
  original_purchase_id TEXT REFERENCES purchases (id),

  supplier_id          TEXT REFERENCES suppliers (id),
  customer_id          TEXT REFERENCES customers (id),

  -- money: PKR whole rupees
  subtotal             INTEGER NOT NULL DEFAULT 0,
  discount             INTEGER NOT NULL DEFAULT 0,
  total                INTEGER NOT NULL DEFAULT 0,
  paid_total           INTEGER NOT NULL DEFAULT 0,

  status               TEXT NOT NULL DEFAULT 'completed'
                       CHECK (status IN ('completed', 'partial', 'pending', 'cancelled')),

  notes                TEXT,
  created_by           TEXT REFERENCES users (id),

  occurred_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  created_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),

  deleted_at           TEXT  -- soft delete
);

CREATE UNIQUE INDEX IF NOT EXISTS purchases_owner_no_uq
  ON purchases (owner_user_id, purchase_no);
