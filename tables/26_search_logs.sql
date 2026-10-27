-- ============================================================
-- TABLE: search_logs
-- Purpose: One row per SEARCH SESSION in the command palette (Ctrl/⌘K) —
-- written when the palette closes, not on every keystroke, so "ca", "cat",
-- "catal", "catalog" is one row and not four.
--
-- This table exists to make the search index better. Two cases carry the
-- value:
--   picked = 1  → they chose something, and picked_rank (0-BASED) says how
--     far down the list it was. A high rank means the right answer existed
--     but was buried — a ranking bug, not a missing keyword.
--   picked = 0 with a non-empty query → they typed and left. Together with
--     result_count = 0 these rows are the most valuable data here: the words
--     the shop reaches for that the index does not know yet. Each one is a
--     keyword to add to software/lib/search-registry.js.
--
-- Read four ways by the owner-only Search Insights page
-- (software/app/(app)/search-insights): most searched terms, dead ends,
-- found-but-buried, and abandoned-despite-results.
--
-- owner_user_id: the tenant. Every shop has its own database, so this is the
--   shop owner's id — the same scoping column as every other table here.
-- actor_id / actor_role / actor_name: who searched. A staff login and the
--   owner reach for different words, and it matters which.
-- source: how the palette was opened — 'sidebar' (the field), 'icon',
--   'shortcut' (Ctrl/Cmd+K), 'slash', 'event'. A shortcut-heavy shop is a
--   shop that has adopted it.
-- query: trimmed and truncated to 120 chars. Rows under 2 chars are never
--   written, and a pick straight off the recents list is not written either
--   (it says nothing about how well the index matches WORDS).
-- result_count: how many rows the list showed for the final query — pages
--   and sections. This log covers the NAVIGATION palette only; the header's
--   record search (invoices / customers / IMEIs) is a separate box asking a
--   separate question, and is not logged here.
-- picked_type: 'page' | 'section'.
-- app_source: 'web' or 'desktop' (software/lib/target.js).
--
-- Created lazily on first write by ensureSearchLogsTable()
-- (software/lib/search-log.js) — the palette must keep working on a shop
-- whose replica has never seen this table.
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

-- Every report is "this shop, newest first".
CREATE INDEX IF NOT EXISTS search_logs_owner_created_idx
  ON search_logs (owner_user_id, created_at DESC);

-- Terms are grouped case-insensitively, so the expression is indexed.
CREATE INDEX IF NOT EXISTS search_logs_owner_query_idx
  ON search_logs (owner_user_id, lower(query));

-- Partial: the dead-end and abandoned reports only ever read rows nobody
-- picked from, which stay a small slice of the table.
CREATE INDEX IF NOT EXISTS search_logs_unpicked_idx
  ON search_logs (owner_user_id, created_at DESC) WHERE picked = 0;
