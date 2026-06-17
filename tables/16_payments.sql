-- ============================================================
-- TABLE: payments
-- Purpose: Every individual payment event (in or out).
-- direction:
--   'in'  → money received from a customer (linked to invoice_id)
--   'out' → money paid to a supplier or customer (linked to purchase_id)
-- Exactly one of invoice_id or purchase_id should be non-NULL.
-- method: payment channel used for this specific payment.
-- reference_no: bank transaction ID, JazzCash ref, cheque no, etc.
-- Multiple payments can link to the same invoice (partial payments,
--   instalment collections, mixed cash+digital).
-- ============================================================

CREATE TABLE IF NOT EXISTS payments (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES users (id),

  direction     TEXT NOT NULL DEFAULT 'in'
                CHECK (direction IN ('in', 'out')),

  method        TEXT NOT NULL DEFAULT 'cash'
                CHECK (method IN ('cash', 'jazzcash', 'easypaisa', 'bank_transfer')),

  -- money: PKR whole rupees
  amount        INTEGER NOT NULL,

  invoice_id    TEXT REFERENCES invoices (id),
  purchase_id   TEXT REFERENCES purchases (id),

  reference_no  TEXT,
  notes         TEXT,

  received_by   TEXT REFERENCES users (id),

  occurred_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS payments_invoice_idx  ON payments (invoice_id);
CREATE INDEX IF NOT EXISTS payments_purchase_idx ON payments (purchase_id);
