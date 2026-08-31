# iLEAD PM Dashboard

Project-management and MEL (Monitoring, Evaluation & Learning) dashboard for the
iLEAD programme — tracking partners, activities, tasks, budgets, and indicator
results against programme targets.

Single-page React app backed by Supabase, deployed on Vercel.

## Stack

| Layer     | Choice |
|-----------|--------|
| UI        | React 19, React Router 7, plain CSS (one stylesheet per component) |
| Build     | Vite 8 |
| Data      | Supabase (Postgres + JS client) |
| Charts    | Recharts |
| Drag/drop | `@hello-pangea/dnd` |
| Icons     | `lucide-react` |
| Hosting   | Vercel (SPA rewrite + one serverless function) |

No TypeScript, no CSS framework.

## Getting started

```bash
npm install
```

Copy the env template and fill in your Supabase project credentials:

```bash
cp .env.example .env.local
```

```
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
```

Then:

```bash
npm run dev
```

Without env vars the app falls back to a stub Supabase client in dev — it renders
but returns empty data and logs a warning. In a production build, missing env
vars throw at startup instead. See [src/utils/supabaseClient.js](src/utils/supabaseClient.js).

The dev server listens on **5173** (`host: true`, so it is reachable from other
devices on your network). Vite prints the real URL on start.

### Scripts

| Command | Does |
|---------|------|
| `npm run dev` | Vite dev server with HMR |
| `npm run build` | Production build to `dist/` |
| `npm run preview` | Serve the production build locally |
| `npm run lint` | ESLint over the repo |
| `npm run backup` | Dump all Supabase tables to `backups/ilead-backup-<timestamp>.json` |

Windows users can double-click `start-ilead.bat`, which runs `npm run dev` and
opens a browser.

## Database

The live schema lives in the Supabase project, but the SQL of record is in the repo:

- [schema_final.sql](schema_final.sql) — core tables
- [migration_budget_line_items.sql](migration_budget_line_items.sql) — `budget_line_items`

Both are idempotent; run them in the Supabase SQL editor.

Core tables:

| Table | Holds |
|-------|-------|
| `partners` | Partner organisations (name, sector, region, colour) |
| `activities` | Work items under a partner — type code, stage, status, ball owner, reach (total / women / men), planned vs actual budget, dates |
| `tasks` | Checklist items under an activity |
| `mel_entries` | Indicator results by quarter, split male/female |
| `activity_indicators` | Per-activity indicator targets and actuals |
| `partner_budgets` | Allocated vs spent per partner |
| `budget_line_items` | Itemised budget detail |

Four further tables — `app_users`, `audit_logs`, `comments`, `activity_types` —
were created directly on the Supabase project and have **no migration file in the
repo**. Recreating the database from scratch will not produce them. If you touch
those, consider writing the SQL down.

Superseded schemas and old JSON exports live in [legacy/](legacy/) — see
[legacy/README.md](legacy/README.md). They do not apply to the current schema.

### Row-level security

RLS is enabled on every table, but each one carries a blanket allow-all policy
for the `anon` role. Anyone holding the anon key can read and write everything.
This is deliberate for the current deployment, not an oversight — but it means
the anon key is a full-access credential and the app is not safe to expose
publicly as-is.

## Authentication

Login is **email-only, no password and no verification**: enter an address, and
[AuthContext](src/context/AuthContext.jsx) looks it up in `app_users`. Unknown
addresses are auto-created with the `viewer` role. The session is a JSON blob in
`localStorage` under `ilead_user`.

This identifies users for attribution and role display; it does not authenticate
them. Anyone can sign in as anyone by typing their email. Roles gate UI, not data
access — see the RLS note above.

## Domain model

Activities move through seven stages (`S1`–`S7`):

Partner Development → AAF Design → Advisor Search → Virtual Assignment →
In-Country Prep → In-Country Implementation → Monitoring

Each activity is typed from a catalogue of ten programme activity types (ToT and
training on RBP/ESG, legal review, the Da Nang RBP index, the SME
self-assessment platform, forums, disability-inclusive guidelines, the national
campaign) plus an ad-hoc type. Each type carries a standard reach and a standard
budget in CAD. MEL indicators are organised into groups with Vietnam and global
targets. All of this lives in [src/utils/constants.js](src/utils/constants.js).

## Routes

| Path | Page |
|------|------|
| `/` | Dashboard |
| `/tasks` | All tasks |
| `/kanban` | Global Kanban |
| `/timeline` | Gantt timeline |
| `/calendar` | Master calendar |
| `/weekly` | Weekly plan |
| `/partner/:id` | Partner detail |
| `/activity/:id` | Activity detail |
| `/report` | Report builder |
| `/project-report` | Project report |
| `/mel-dashboard` | MEL dashboard |
| `/mel-entry` | MEL data entry |
| `/activity-log` | Audit log |
| `/settings` | Settings and user management |

Mobile gets a bottom nav bar and a quick-task sheet.

## Layout

```
src/
  pages/       one folder-less file per route, each with its own .css
  components/  shared UI — Sidebar, Topbar, KanbanBoard, GanttTimeline, modals
  components/forms/  Activity, Task, Partner, Contact forms + MEL wizard
  context/     DataContext (all Supabase reads/writes), Auth, Toast, Confirm
  utils/       constants, supabaseClient, store, insights, reportGenerator
api/
  gcal-proxy.js   Vercel function proxying public Google Calendar ICS feeds
scripts/
  backup.js            manual JSON backup of all tables
  fetch-activities.mjs
```

`DataContext` is the single data layer — every table read and mutation goes
through it, and pages consume it via hook rather than calling Supabase directly.

## Deployment

Vercel. [vercel.json](vercel.json) rewrites all paths to `index.html` for
client-side routing. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in the
Vercel project environment or the production build will throw on load.

The `/api/gcal-proxy` function fetches public Google Calendar ICS feeds
server-side to dodge CORS; it only accepts `calendar.google.com` URLs.
