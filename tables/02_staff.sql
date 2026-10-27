-- ============================================================
-- TABLE: staff
-- Purpose: Cashier / salesman logins for the counter software.
-- Lives in each shop's TENANT database (created on demand by
-- mobipos-admin/lib/tenant-db.js), NOT the shared control DB —
-- the `users` table is kept purely for shop owners (admins).
--
-- Login (mobipos-software) queries `users` and `staff` in
-- parallel; a staff match's user_id identifies the owner/shop
-- the cashier belongs to, and its data scope.
--
-- password stored as plain text (V1 — hash in V2).
-- permissions is a JSON page-key -> bool map, e.g.
--   {"page.pos":true,"page.customers":false}. NULL = all pages.
-- staff_role is a descriptive job title (cashier/salesman/
--   technician/manager/other/free-text), not an auth role.
-- can_login: 1 = normal counter login (email+password required).
--   0 = attribution-only "employee" — exists purely to be picked as the
--   salesperson on a sale (invoices.sold_by_staff_id) and never signs in.
--   Lets a shop track commission for people who don't operate the register.
-- ============================================================

CREATE TABLE IF NOT EXISTS staff (
  id           TEXT PRIMARY KEY NOT NULL,

  user_id      TEXT NOT NULL,          -- owner (users.id) this staff belongs to

  full_name    TEXT NOT NULL,
  username     TEXT,
  password     TEXT NOT NULL,

  staff_role   TEXT,
  phone        TEXT,
  email        TEXT,
  permissions  TEXT,

  can_login    INTEGER NOT NULL DEFAULT 1
               CHECK (can_login IN (0, 1)),

  is_active    INTEGER NOT NULL DEFAULT 1
               CHECK (is_active IN (0, 1)),

  created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS staff_user_id_idx ON staff (user_id);
