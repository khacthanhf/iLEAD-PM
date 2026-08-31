-- =============================================================
-- iLEAD — Sprint 3 Migration
-- Chạy trong Supabase SQL Editor SAU KHI đã chạy schema_sprint2.sql
-- =============================================================

-- ─────────────────────────────────────────
-- 1. VERSION FIELD — Optimistic Locking
--    Mỗi lần UPDATE, version tự tăng 1.
--    Client so sánh version trước khi save
--    để phát hiện xung đột đồng thời.
-- ─────────────────────────────────────────
ALTER TABLE projects    ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 0;
ALTER TABLE activities  ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 0;
ALTER TABLE tasks       ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 0;

-- Auto-increment version on every UPDATE
CREATE OR REPLACE FUNCTION _increment_version()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.version = OLD.version + 1;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_version_projects   ON projects;
DROP TRIGGER IF EXISTS trg_version_activities ON activities;
DROP TRIGGER IF EXISTS trg_version_tasks      ON tasks;

CREATE TRIGGER trg_version_projects
  BEFORE UPDATE ON projects
  FOR EACH ROW EXECUTE FUNCTION _increment_version();

CREATE TRIGGER trg_version_activities
  BEFORE UPDATE ON activities
  FOR EACH ROW EXECUTE FUNCTION _increment_version();

CREATE TRIGGER trg_version_tasks
  BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION _increment_version();

-- ─────────────────────────────────────────
-- 2. NOTIFICATION LOG (optional, dùng cho Sprint 4 email alerts)
--    Lưu lịch sử notification đã gửi để tránh gửi trùng.
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notification_log (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  notif_key  TEXT        NOT NULL UNIQUE,  -- e.g. 'deadline_act_abc123_2026-04-25'
  sent_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_key ON notification_log(notif_key);

-- RLS
ALTER TABLE notification_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "anon_all" ON notification_log FOR ALL USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────
-- 3. VERIFY
-- ─────────────────────────────────────────
SELECT 'Sprint 3 migration complete' AS status;
