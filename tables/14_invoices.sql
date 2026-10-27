-- ============================================================
-- TABLE: invoices
-- Purpose: Records every sale or return transaction.
-- type:
--   'sale'   → normal sale to customer
--   'return' → customer returning item (original_invoice_id set)
-- sale_mode: snapshot of payment method at time of sale.
--   Stored here so invoice lists don't need to JOIN payments.
--   'cash' | 'jazzcash' | 'easypaisa' | 'bank_transfer'
--   'credit' = khata/udhaar (paid_total = 0, balance owed)
--   'mixed'  = partial payment + partial credit
--   A coarse enum, deliberately: the precise method lives on the payment row
--   (payments_new.method / payment_account_id), which is what invoice lists and
--   receipts label a sale from. POS options this enum has no value for map onto
--   the nearest one — "unpaid" is stored as 'credit' (money owed, just not on
--   anyone's khata), and a complementary (free) sale as 'mixed', the one value
--   that names no real account, with method 'complementary' on its payment row
--   and a matching expense under the "Complementary" category.
-- paid_total: sum of linked payments WHERE direction = 'in'.
-- change_due: cash returned to customer (paidAmount - total).
-- void_reason: populated when status = 'cancelled'.
-- status:
--   'completed' → fully paid
--   'partial'   → partially paid (khata balance remains)
--   'pending'   → not yet paid
--   'cancelled' → voided
-- sold_by_staff_id: who gets commission credit for this sale (staff.id, this
--   tenant DB's own staff table). NULL = the shop owner rang it up themself.
--   Deliberately separate from created_by (the logged-in operator, for audit)
--   so a sale can be credited to a salesperson even if an admin or a different
--   cashier processed the payment.
-- ============================================================

CREATE TABLE IF NOT EXISTS invoices (
  id                   TEXT PRIMARY KEY NOT NULL,
  owner_user_id        TEXT NOT NULL REFERENCES users (id),

  invoice_no           TEXT NOT NULL,

  type                 TEXT NOT NULL DEFAULT 'sale'
                       CHECK (type IN ('sale', 'return')),
  original_invoice_id  TEXT REFERENCES invoices (id),

  customer_id          TEXT REFERENCES customers (id),
  sold_by_staff_id     TEXT REFERENCES staff (id),

  sale_mode            TEXT NOT NULL DEFAULT 'cash'
                       CHECK (sale_mode IN ('cash', 'jazzcash', 'easypaisa', 'bank_transfer', 'credit', 'mixed')),

  -- money: PKR whole rupees
  subtotal             INTEGER NOT NULL DEFAULT 0,
  discount             INTEGER NOT NULL DEFAULT 0,
  tax_total            INTEGER NOT NULL DEFAULT 0,
  total                INTEGER NOT NULL DEFAULT 0,
  paid_total           INTEGER NOT NULL DEFAULT 0,
  change_due           INTEGER NOT NULL DEFAULT 0,

  status               TEXT NOT NULL DEFAULT 'completed'
                       CHECK (status IN ('completed', 'partial', 'pending', 'cancelled')),

  void_reason          TEXT,

  notes                TEXT,
  created_by           TEXT REFERENCES users (id),

  occurred_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  created_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),

  deleted_at           TEXT  -- soft delete
);

CREATE UNIQUE INDEX IF NOT EXISTS invoices_owner_no_uq
  ON invoices (owner_user_id, invoice_no);

CREATE INDEX IF NOT EXISTS invoices_customer_idx
  ON invoices (customer_id);

CREATE INDEX IF NOT EXISTS invoices_sold_by_staff_idx
  ON invoices (sold_by_staff_id);
