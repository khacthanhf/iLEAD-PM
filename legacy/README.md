# Legacy files

Superseded files kept for reference — not used by the app.

- `activities*.json` — old data exports from earlier schema generations. Live data now lives in Supabase (seeded 2026-08-27).
- `schema.sql`, `schema_v2.sql`, `schema_sprint2–5.sql` — earlier schema generations (uuid ids, `projects` table). They do not apply to the current TEXT-id schema and contain invalid `CREATE POLICY IF NOT EXISTS` syntax.
- `mockup-layer3.html` — early UI mockup.

Current schema = `schema_final.sql` + `migration_budget_line_items.sql` (repo root), plus the `app_users` / `audit_logs` / `comments` / `activity_types` tables created directly on the Supabase project.
