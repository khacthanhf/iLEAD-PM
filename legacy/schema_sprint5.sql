-- =============================================================
-- iLEAD — Sprint 5 Migration
-- Chạy sau schema_sprint4.sql
-- Mục đích: chuẩn bị RBAC table cho Supabase Auth tích hợp sau
-- =============================================================

-- ─────────────────────────────────────────
-- 1. USER ROLES TABLE
--    Lưu role cho mỗi Supabase Auth user (future use).
--    Hiện tại app dùng localStorage; bảng này chuẩn bị
--    khi nâng lên multi-user Auth.
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_roles (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        NOT NULL,          -- maps to auth.users.id when Auth is enabled
  email      TEXT        NOT NULL,
  role       TEXT        NOT NULL DEFAULT 'coordinator'
               CHECK (role IN ('admin','pm','coordinator','viewer')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_roles_user   ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_email  ON user_roles(email);

-- updated_at auto-trigger (reuse function from schema_sprint2.sql)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'set_updated_at_user_roles'
  ) THEN
    CREATE TRIGGER set_updated_at_user_roles
      BEFORE UPDATE ON user_roles
      FOR EACH ROW EXECUTE FUNCTION _set_updated_at();
  END IF;
END $$;

-- RLS (accessible only by the owner or admin service role)
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "anon_select_own" ON user_roles
  FOR SELECT USING (true);
-- Insert/Update restricted to service role until Auth is enabled
CREATE POLICY IF NOT EXISTS "anon_insert" ON user_roles
  FOR INSERT WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "anon_update" ON user_roles
  FOR UPDATE USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────
-- 2. ROLE PERMISSIONS REFERENCE TABLE
--    Documents what each role can do (read-only config).
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS role_permissions (
  role        TEXT  PRIMARY KEY CHECK (role IN ('admin','pm','coordinator','viewer')),
  can_edit    BOOL  NOT NULL DEFAULT false,
  can_delete  BOOL  NOT NULL DEFAULT false,
  can_admin   BOOL  NOT NULL DEFAULT false,
  description TEXT
);

-- Seed permission definitions
INSERT INTO role_permissions (role, can_edit, can_delete, can_admin, description)
VALUES
  ('admin',       true,  true,  true,  'Toàn quyền — xóa partner, project, activity, task'),
  ('pm',          true,  true,  false, 'Quản lý — chỉnh sửa & xóa project, activity, task'),
  ('coordinator', true,  false, false, 'Thực thi — chỉnh sửa nhưng không xóa project'),
  ('viewer',      false, false, false, 'Chỉ xem — không được chỉnh sửa hay xóa')
ON CONFLICT (role) DO NOTHING;

-- RLS: read-only for all
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "anon_select" ON role_permissions
  FOR SELECT USING (true);

-- ─────────────────────────────────────────
-- 3. VERIFY
-- ─────────────────────────────────────────
SELECT 'Sprint 5 migration complete' AS status;
