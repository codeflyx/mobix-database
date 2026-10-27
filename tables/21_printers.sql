-- Thermal printer configuration (USB/COM + Windows USB Printer Class).
-- IP/network printing is intentionally not modelled.

CREATE TABLE IF NOT EXISTS printers (
  id                TEXT PRIMARY KEY NOT NULL,
  owner_user_id     TEXT NOT NULL REFERENCES users (id),
  name              TEXT NOT NULL,

  -- 'usb'         → serial/COM printer, print via `copy /b file COMx`
  -- 'windows_usb' → installed Windows printer (USB001), print via winspool RAW
  -- 'network'     → ESC/POS over TCP to ip_address:ip_port (usually 9100)
  connection_type   TEXT NOT NULL DEFAULT 'usb'
                    CHECK (connection_type IN ('usb', 'windows_usb', 'network')),

  usb_port          TEXT,            -- "COM3"  (connection_type = 'usb')
  usb_printer_name  TEXT,            -- Windows printer name (connection_type = 'windows_usb')
  ip_address        TEXT,            -- "192.168.1.50" (connection_type = 'network')
  ip_port           INTEGER,         -- 9100 (connection_type = 'network')

  paper_width       INTEGER NOT NULL DEFAULT 48,   -- chars per line: 32=58mm, 42=72mm, 48=80mm
  model             TEXT,

  is_default        INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1)),
  is_active         INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  last_connected_at TEXT,

  created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS printers_owner_idx ON printers (owner_user_id);
