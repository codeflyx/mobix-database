-- ============================================================
-- TABLE: supplier_documents
-- Purpose: Stores uploaded documents for a supplier.
-- Mirrors customer_documents exactly.
-- document_type: 'cnic_front' | 'cnic_back' | 'agreement' | 'other'
-- file_url: path or URL to the stored file (local or cloud).
-- ============================================================

CREATE TABLE IF NOT EXISTS supplier_documents (
  id             TEXT PRIMARY KEY NOT NULL,
  supplier_id    TEXT NOT NULL REFERENCES suppliers (id),

  document_type  TEXT NOT NULL,
  file_url       TEXT NOT NULL,
  notes          TEXT,

  created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
