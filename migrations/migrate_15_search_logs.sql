-- ============================================================
-- Migration 15: search_logs
--
-- Backs the command palette (Ctrl/⌘K) in the shop software. Applied
-- additively and idempotently by the app itself — ensureSearchLogsTable()
-- in software/lib/search-log.js runs on the first logged search — so no
-- manual run is needed. This file is the canonical record of what that
-- bootstrap does.
--
-- WHY
--   The palette indexes pages AND the sections inside them, with keywords
--   and aliases typed out by hand in software/lib/search-registry.js. A
--   hand-maintained keyword list is wrong within two sprints unless
--   something tells you WHICH words are missing. This table is that
--   something: one row per search session, written when the palette
--   closes.
--
--   The two rows that matter are the ones that look like failures:
--     · result_count = 0        → the index has never heard of that word
--     · picked = 0, results > 0 → the list had rows, none were right
--   Those are read back on the owner-only Search Insights page and turned
--   into keywords. picked_rank (0-based) catches the other failure mode:
--   the answer was there, four rows down.
--
-- NOT per keystroke. "ca" / "cat" / "catal" / "catalog" is ONE row, so the
-- counts mean "how many people went looking", not "how fast they type".
--
-- SCOPE
--   Every shop has its own database, so owner_user_id is the tenant and no
--   cross-shop column is needed. A failed insert is swallowed after a
--   console.error: logging must never interfere with the navigation the
--   user asked for, and search must keep working with this table absent.
-- ============================================================

CREATE TABLE IF NOT EXISTS search_logs (
  id            TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL,

  actor_id      TEXT,
  actor_role    TEXT,
  actor_name    TEXT,

  source        TEXT NOT NULL DEFAULT 'palette',
  query         TEXT NOT NULL,
  query_length  INTEGER NOT NULL DEFAULT 0,
  result_count  INTEGER NOT NULL DEFAULT 0,

  picked        INTEGER NOT NULL DEFAULT 0 CHECK (picked IN (0, 1)),
  picked_title  TEXT,
  picked_href   TEXT,
  picked_type   TEXT,
  picked_rank   INTEGER,

  app_source    TEXT,
  user_agent    TEXT,
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS search_logs_owner_created_idx
  ON search_logs (owner_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS search_logs_owner_query_idx
  ON search_logs (owner_user_id, lower(query));

CREATE INDEX IF NOT EXISTS search_logs_unpicked_idx
  ON search_logs (owner_user_id, created_at DESC) WHERE picked = 0;
