-- ============================================================
-- schema_v2.sql  —  iLEAD PM  ·  3-tier refactor
-- Run this in your Supabase SQL Editor
-- ============================================================

-- ── 1. Activity Type Catalog ──────────────────────────────────
CREATE TABLE IF NOT EXISTS activity_types (
  code                TEXT PRIMARY KEY,
  name                TEXT NOT NULL,
  name_vi             TEXT,
  standard_reach      INT  DEFAULT 0,
  standard_budget_cad NUMERIC(10,2) DEFAULT 0,
  created_at          TIMESTAMPTZ DEFAULT now()
);

INSERT INTO activity_types (code, name, name_vi, standard_reach, standard_budget_cad) VALUES
  ('1A','ToT – Civil servants on RBP/ESG',        'ToT cán bộ công chức về RBP/ESG',              25, 10000),
  ('1B','ToT – SMEs on RBP/ESG',                  'ToT doanh nghiệp SME về RBP/ESG',              25, 10000),
  ('2A','Training RBP – Civil servants',           'Đào tạo RBP cho cán bộ công chức',             50, 10000),
  ('2B','Training RBP – SMEs',                    'Đào tạo RBP cho SME',                          50, 10000),
  ('3', 'Legal review & policy recommendations',  'Rà soát pháp lý & khuyến nghị chính sách RBP',100, 10000),
  ('4', 'Da Nang RBP Index & ESG dashboard',      'Chỉ số RBP Đà Nẵng & ESG dashboard',          100, 15000),
  ('5', 'Digital RBP self-assessment platform',   'Nền tảng tự đánh giá RBP số cho SME',         300, 20000),
  ('6', 'RBP Forum / Conference',                 'Diễn đàn / Hội thảo RBP',                     230, 25000),
  ('7', 'Disability-inclusive RBP guideline',     'Hướng dẫn RBP hòa nhập người khuyết tật',     100,  4000),
  ('8', 'National RBP marketing campaign',        'Chiến dịch truyền thông RBP quốc gia',         300, 15000)
ON CONFLICT (code) DO NOTHING;


-- ── 2. Indicator Code Catalog ─────────────────────────────────
CREATE TABLE IF NOT EXISTS indicator_codes (
  code        TEXT PRIMARY KEY,
  label       TEXT NOT NULL,
  output_area TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);

INSERT INTO indicator_codes (code, label, output_area) VALUES
  ('1111.3','TA to govt: awareness on RBP policies/laws',                    '1111'),
  ('1111.4','TA to govt: develop/apply/comply with RBP frameworks',          '1111'),
  ('1112.2','TA to govt: data collection & analysis on RBP',                 '1112'),
  ('1112.3','TA to govt: digital governance platforms',                      '1112'),
  ('1112.4','TA to govt: monitoring RBP policies implementation',            '1112'),
  ('1121.2','Connect agencies on inclusive decision-making',                 '1121'),
  ('1122.2','TA: communication strategy on RBP for government',              '1122'),
  ('1211.2','TA: participatory approaches to engage communities',            '1211'),
  ('1211.3','Organize & deliver public consultations on RBP',                '1211'),
  ('1212.2','TA: testing public-private engagement mechanisms',              '1212'),
  ('1221.2','TA to communities: awareness of rights/impacts on RBP',        '1221'),
  ('1221.3','TA to local businesses: implement & comply with RBP',          '1221'),
  ('1221.4','Develop & deliver public awareness campaigns on RBP',           '1221'),
  ('1221.5','TA: community consultations and feedback mechanisms',           '1221'),
  ('1222.2','TA: digital platforms for community engagement on RBP',        '1222')
ON CONFLICT (code) DO NOTHING;


-- ── 3. Add new columns to activities ─────────────────────────
ALTER TABLE activities
  ADD COLUMN IF NOT EXISTS "partnerId"        UUID REFERENCES partners(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS "activityTypeCode" TEXT REFERENCES activity_types(code),
  ADD COLUMN IF NOT EXISTS iteration          INT DEFAULT 1,
  ADD COLUMN IF NOT EXISTS "reachTotal"       INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "reachWomen"       INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "reachMen"         INT DEFAULT 0;

-- Migrate existing data: pull partnerId from parent project
UPDATE activities a
SET "partnerId" = p."partnerId"
FROM projects p
WHERE a."projectId" = p.id
  AND a."partnerId" IS NULL;


-- ── 4. Activity ↔ Indicator junction table ───────────────────
CREATE TABLE IF NOT EXISTS activity_indicators (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "activityId"    UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  "indicatorCode" TEXT NOT NULL REFERENCES indicator_codes(code),
  "targetCount"   INT DEFAULT 0,
  "actualCount"   INT DEFAULT 0,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  UNIQUE("activityId", "indicatorCode")
);

CREATE INDEX IF NOT EXISTS idx_ai_activity ON activity_indicators("activityId");


-- ── 5. RLS ────────────────────────────────────────────────────
ALTER TABLE activity_types      ENABLE ROW LEVEL SECURITY;
ALTER TABLE indicator_codes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_indicators ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='anon_all_activity_types') THEN
    CREATE POLICY "anon_all_activity_types" ON activity_types      FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='anon_all_indicator_codes') THEN
    CREATE POLICY "anon_all_indicator_codes" ON indicator_codes     FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='anon_all_act_indicators') THEN
    CREATE POLICY "anon_all_act_indicators"  ON activity_indicators FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
END $$;
