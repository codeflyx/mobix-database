-- ============================================================
-- TABLE: customer_documents
-- Purpose: Stores uploaded documents for a customer.
-- document_type: 'cnic_front' | 'cnic_back' | 'agreement' | 'other'
-- file_url: path or URL to the stored file (local or cloud).
-- No soft delete — documents are deleted with the customer record.
-- ============================================================

CREATE TABLE IF NOT EXISTS customer_documents (
  id             TEXT PRIMARY KEY NOT NULL,
  customer_id    TEXT NOT NULL REFERENCES customers (id),

  document_type  TEXT NOT NULL,
  file_url       TEXT NOT NULL,
  notes          TEXT,

  created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
