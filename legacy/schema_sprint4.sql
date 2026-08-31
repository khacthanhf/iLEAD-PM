-- =============================================================
-- iLEAD — Sprint 4 Migration
-- Chạy sau schema_sprint3.sql
-- =============================================================

-- ─────────────────────────────────────────
-- 1. COMMENTS TABLE
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS comments (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id UUID        NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  author      TEXT        NOT NULL,
  text        TEXT        NOT NULL CHECK (length(trim(text)) > 0),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comments_activity ON comments(activity_id);
CREATE INDEX IF NOT EXISTS idx_comments_created  ON comments(created_at DESC);

-- RLS
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "anon_select" ON comments FOR SELECT USING (true);
CREATE POLICY IF NOT EXISTS "anon_insert" ON comments FOR INSERT WITH CHECK (true);
-- Only allow delete by same author (enforced at app level; DB policy below is permissive for now)
CREATE POLICY IF NOT EXISTS "anon_delete" ON comments FOR DELETE USING (true);

-- Realtime: enable for comments table so ActivityComments gets live updates
-- (Run this separately if needed: ALTER PUBLICATION supabase_realtime ADD TABLE comments;)

-- ─────────────────────────────────────────
-- 2. ACTIVITY DEPENDENCIES
--    Stores "activity B is blocked by activity A"
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS activity_dependencies (
  id              UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id     UUID  NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  blocked_by_id   UUID  NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(activity_id, blocked_by_id)
);

CREATE INDEX IF NOT EXISTS idx_dep_activity  ON activity_dependencies(activity_id);
CREATE INDEX IF NOT EXISTS idx_dep_blocker   ON activity_dependencies(blocked_by_id);

ALTER TABLE activity_dependencies ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "anon_all" ON activity_dependencies
  FOR ALL USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────
-- 3. VERIFY
-- ─────────────────────────────────────────
SELECT 'Sprint 4 migration complete' AS status;
