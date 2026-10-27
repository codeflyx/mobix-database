-- ============================================================
--  Migration 06 — Receipt content settings (one row per owner)
--  Drives what prints on the thermal receipt + branding images.
--  Booleans are INTEGER 0/1 and default to 1 (everything on).
--  Safe to re-run (IF NOT EXISTS).
-- ============================================================

CREATE TABLE IF NOT EXISTS receipt_settings (
  id                  TEXT PRIMARY KEY NOT NULL,
  owner_user_id       TEXT NOT NULL UNIQUE REFERENCES users (id),

  -- Business info / text content
  store_name          TEXT,
  phone1              TEXT,
  phone2              TEXT,
  email               TEXT,
  address             TEXT,
  tagline_text        TEXT,
  thankyou_text       TEXT,
  footer_note_text    TEXT,
  branding_text       TEXT,

  -- Branding images (Cloudinary secure URLs) + print sizes (px width)
  logo_url            TEXT,
  qr_url              TEXT,
  logo_size           INTEGER NOT NULL DEFAULT 300,
  qr_size             INTEGER NOT NULL DEFAULT 250,

  -- Reusable upload history (JSON arrays of { name, url })
  logo_library        TEXT NOT NULL DEFAULT '[]',
  qr_library          TEXT NOT NULL DEFAULT '[]',

  -- Header toggles
  show_logo           INTEGER NOT NULL DEFAULT 1 CHECK (show_logo IN (0,1)),
  show_shop_name      INTEGER NOT NULL DEFAULT 1 CHECK (show_shop_name IN (0,1)),
  show_tagline        INTEGER NOT NULL DEFAULT 1 CHECK (show_tagline IN (0,1)),
  show_address        INTEGER NOT NULL DEFAULT 1 CHECK (show_address IN (0,1)),
  show_phone          INTEGER NOT NULL DEFAULT 1 CHECK (show_phone IN (0,1)),
  show_email          INTEGER NOT NULL DEFAULT 1 CHECK (show_email IN (0,1)),

  -- Transaction-detail toggles
  show_invoice_no     INTEGER NOT NULL DEFAULT 1 CHECK (show_invoice_no IN (0,1)),
  show_datetime       INTEGER NOT NULL DEFAULT 1 CHECK (show_datetime IN (0,1)),
  show_cashier        INTEGER NOT NULL DEFAULT 1 CHECK (show_cashier IN (0,1)),
  show_customer       INTEGER NOT NULL DEFAULT 1 CHECK (show_customer IN (0,1)),
  show_customer_phone INTEGER NOT NULL DEFAULT 1 CHECK (show_customer_phone IN (0,1)),
  show_payment_method INTEGER NOT NULL DEFAULT 1 CHECK (show_payment_method IN (0,1)),

  -- Footer toggles
  show_thankyou       INTEGER NOT NULL DEFAULT 1 CHECK (show_thankyou IN (0,1)),
  show_footer_note    INTEGER NOT NULL DEFAULT 1 CHECK (show_footer_note IN (0,1)),
  show_qr             INTEGER NOT NULL DEFAULT 1 CHECK (show_qr IN (0,1)),
  show_branding       INTEGER NOT NULL DEFAULT 1 CHECK (show_branding IN (0,1)),

  -- Print behaviour
  auto_print          INTEGER NOT NULL DEFAULT 1 CHECK (auto_print IN (0,1)),
  copies              INTEGER NOT NULL DEFAULT 1,
  beep                INTEGER NOT NULL DEFAULT 1 CHECK (beep IN (0,1)),

  created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  updated_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);
