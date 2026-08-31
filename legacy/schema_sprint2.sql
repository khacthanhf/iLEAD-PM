-- =============================================================
-- iLEAD — Sprint 2 Migration
-- Run in Supabase SQL Editor (safe to run on existing data)
-- =============================================================

-- ─────────────────────────────────────────
-- 1. BUDGET FIELDS on projects & activities
-- ─────────────────────────────────────────
ALTER TABLE projects
  ADD COLUMN IF NOT EXISTS budget_planned NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS budget_actual  NUMERIC DEFAULT 0;

ALTER TABLE activities
  ADD COLUMN IF NOT EXISTS budget_planned NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS budget_actual  NUMERIC DEFAULT 0;

-- ─────────────────────────────────────────
-- 2. AUDIT LOG TABLE
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_logs (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tbl         TEXT        NOT NULL,   -- 'partners' | 'projects' | 'activities' | 'tasks'
  record_id   TEXT        NOT NULL,   -- PK of the changed record
  action      TEXT        NOT NULL    -- 'created' | 'updated' | 'deleted'
              CHECK (action IN ('created','updated','deleted')),
  field       TEXT,                   -- field name (UPDATE only, NULL for create/delete)
  old_val     TEXT,                   -- previous value cast to text
  new_val     TEXT,                   -- new value cast to text
  changed_by  TEXT,                   -- ilead_author_name from localStorage
  changed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for fast per-record and time-based queries
CREATE INDEX IF NOT EXISTS idx_audit_record  ON audit_logs(tbl, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_time    ON audit_logs(changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_user    ON audit_logs(changed_by);

-- RLS: same policy as other tables
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "anon_select" ON audit_logs FOR SELECT USING (true);
CREATE POLICY IF NOT EXISTS "anon_insert" ON audit_logs FOR INSERT WITH CHECK (true);
-- Audit logs are immutable — no UPDATE or DELETE policies

-- ─────────────────────────────────────────
-- 3. OPTIONAL: DB-level trigger for extra safety
--    Captures changes even if the client skips logging.
--    Logs every column change on UPDATE as a separate row.
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION _audit_log_trigger()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  col TEXT;
  old_v TEXT;
  new_v TEXT;
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO audit_logs(tbl, record_id, action, changed_by)
    VALUES (TG_TABLE_NAME, NEW.id::TEXT, 'created', NEW.author);

  ELSIF TG_OP = 'UPDATE' THEN
    -- Log each changed column individually
    FOR col IN
      SELECT column_name FROM information_schema.columns
      WHERE table_name = TG_TABLE_NAME
        AND column_name NOT IN ('id','author','created_at','updated_at','pos')
    LOOP
      EXECUTE format('SELECT ($1).%I::TEXT, ($2).%I::TEXT', col, col)
        INTO old_v, new_v USING OLD, NEW;
      IF old_v IS DISTINCT FROM new_v THEN
        INSERT INTO audit_logs(tbl, record_id, action, field, old_val, new_val, changed_by)
        VALUES (TG_TABLE_NAME, NEW.id::TEXT, 'updated', col, old_v, new_v, NEW.author);
      END IF;
    END LOOP;

  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO audit_logs(tbl, record_id, action, changed_by)
    VALUES (TG_TABLE_NAME, OLD.id::TEXT, 'deleted', OLD.author);
  END IF;
  RETURN NEW;
END;
$$;

-- Attach trigger to all 4 tables
DROP TRIGGER IF EXISTS trg_audit_partners   ON partners;
DROP TRIGGER IF EXISTS trg_audit_projects   ON projects;
DROP TRIGGER IF EXISTS trg_audit_activities ON activities;
DROP TRIGGER IF EXISTS trg_audit_tasks      ON tasks;

CREATE TRIGGER trg_audit_partners
  AFTER INSERT OR UPDATE OR DELETE ON partners
  FOR EACH ROW EXECUTE FUNCTION _audit_log_trigger();

CREATE TRIGGER trg_audit_projects
  AFTER INSERT OR UPDATE OR DELETE ON projects
  FOR EACH ROW EXECUTE FUNCTION _audit_log_trigger();

CREATE TRIGGER trg_audit_activities
  AFTER INSERT OR UPDATE OR DELETE ON activities
  FOR EACH ROW EXECUTE FUNCTION _audit_log_trigger();

CREATE TRIGGER trg_audit_tasks
  AFTER INSERT OR UPDATE OR DELETE ON tasks
  FOR EACH ROW EXECUTE FUNCTION _audit_log_trigger();

-- ─────────────────────────────────────────
-- 4. VERIFY
-- ─────────────────────────────────────────
SELECT 'Sprint 2 migration complete' AS status;
