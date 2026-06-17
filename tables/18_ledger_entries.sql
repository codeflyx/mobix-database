-- ============================================================
-- TABLE: ledger_entries
-- Purpose: Double-entry khata/credit ledger for customers and
--   suppliers. Each row records a debit or credit event.
-- party_type: 'customer' or 'supplier'.
-- amount:
--   Positive → party owes us money (debit / receivable).
--   Negative → we owe party money (credit / payable).
-- reason values (not enforced by CHECK — extensible):
--   'sale_on_credit'      → customer bought on credit
--   'payment_received'    → customer paid their due
--   'purchase_on_credit'  → we bought from supplier on credit
--   'payment_made'        → we paid the supplier
--   'adjustment'          → manual correction or return reversal
-- deleted_at: soft delete — filtered out in all queries.
-- ============================================================

CREATE TABLE IF NOT EXISTS ledger_entries (
  id               TEXT PRIMARY KEY NOT NULL,
  owner_user_id    TEXT NOT NULL REFERENCES users (id),

  party_type       TEXT NOT NULL CHECK (party_type IN ('customer', 'supplier')),

  customer_id      TEXT REFERENCES customers (id),
  supplier_id      TEXT REFERENCES suppliers (id),

  -- money: positive = owed to us, negative = we owe
  amount           INTEGER NOT NULL,
  reason           TEXT NOT NULL,

  ref_purchase_id  TEXT REFERENCES purchases (id),
  ref_payment_id   TEXT REFERENCES payments (id),
  ref_invoice_id   TEXT REFERENCES invoices (id),

  notes            TEXT,
  created_by       TEXT REFERENCES users (id),

  occurred_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  deleted_at       TEXT
);

CREATE INDEX IF NOT EXISTS ledger_entries_customer_idx
  ON ledger_entries (owner_user_id, customer_id);
CREATE INDEX IF NOT EXISTS ledger_entries_supplier_idx
  ON ledger_entries (owner_user_id, supplier_id);
