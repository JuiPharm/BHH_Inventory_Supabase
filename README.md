# BHH Inventory Management System

Production-grade hospital inventory web application using **React + Vite + Netlify** as static frontend and **Supabase PostgreSQL/Auth/RLS/RPC** as backend/database.

## Core Architecture

```txt
Netlify Static Frontend
  └─ React + Vite + supabase-js
      └─ Supabase
          ├─ Auth
          ├─ PostgreSQL normalized schema
          ├─ Row Level Security
          ├─ SQL RPC for stock movement
          ├─ Views for dashboard/reports
          ├─ Audit triggers
          └─ Storage for item images
```

## Important Security Rules

- Use only `VITE_SUPABASE_ANON_KEY` in frontend.
- Never expose `service_role` key in frontend or Netlify public variables.
- Never update `stock_balances` directly from UI.
- Use SQL RPC functions for receive, issue, adjustment, transfer, and stock count approval.
- Keep RLS enabled.
- Every stock movement writes `stock_transactions`.
- FEFO is handled in `issue_stock()` when `lot_id` is not specified.

## Folder Structure

```txt
BHH_Inventory_Netlify_Complete/
├─ netlify.toml
├─ package.json
├─ vite.config.ts
├─ index.html
├─ public/
│  ├─ _redirects
│  └─ favicon.svg
├─ src/
│  ├─ components/
│  ├─ lib/
│  ├─ pages/
│  ├─ services/
│  ├─ state/
│  ├─ styles/
│  ├─ types/
│  └─ utils/
├─ supabase/
│  ├─ schema.sql
│  ├─ triggers.sql
│  ├─ views.sql
│  ├─ functions.sql
│  ├─ rls_policies.sql
│  ├─ storage_policies.sql
│  ├─ seed.sql
│  └─ all_in_one.sql
├─ DEPLOYMENT_NETLIFY.md
├─ TESTING_CHECKLIST.md
├─ PRODUCTION_CHECKLIST.md
└─ SECURITY_NOTES.md
```

## Local Development

```bash
npm install
cp .env.example .env.local
npm run dev
```

Fill `.env.local`:

```env
VITE_SUPABASE_URL=https://your-project-id.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-public-key
VITE_APP_NAME=BHH Inventory Management System
VITE_BASE_PATH=/
```

## Supabase Setup

Run SQL files in this order:

```txt
1. supabase/schema.sql
2. supabase/triggers.sql
3. supabase/views.sql
4. supabase/functions.sql
5. supabase/rls_policies.sql
6. supabase/storage_policies.sql
7. supabase/seed.sql
```

Or run:

```txt
supabase/all_in_one.sql
```

## Create First Admin User

1. Create user in Supabase Auth.
2. Run this SQL after replacing email:

```sql
update public.profiles
set role_id = (select id from public.roles where role_code='super_admin'),
    is_active = true,
    default_warehouse_id = (select id from public.warehouses where warehouse_code='MAIN')
where email = 'your-admin-email@hospital.com';

insert into public.user_warehouse_access(user_id, warehouse_id, can_receive, can_issue, can_adjust, can_transfer)
select id, (select id from public.warehouses where warehouse_code='MAIN'), true, true, true, true
from public.profiles
where email = 'your-admin-email@hospital.com'
on conflict do nothing;
```

If profile does not auto-create, insert manually:

```sql
insert into public.profiles(id, email, full_name, role_id, default_warehouse_id, is_active)
select id, email, email,
       (select id from public.roles where role_code='super_admin'),
       (select id from public.warehouses where warehouse_code='MAIN'),
       true
from auth.users
where email = 'your-admin-email@hospital.com'
on conflict (id) do update
set role_id = excluded.role_id,
    default_warehouse_id = excluded.default_warehouse_id,
    is_active = true;
```

## Netlify Deploy

Build command:

```txt
npm run build
```

Publish directory:

```txt
dist
```

Environment variables:

```txt
VITE_SUPABASE_URL
VITE_SUPABASE_ANON_KEY
VITE_APP_NAME
VITE_BASE_PATH
```

## Pages Included

- Login / Reset password
- Dashboard
- Item Master
- Stock Balance
- Receive Stock
- Issue Stock
- Adjustment
- Transfer
- Stock Count
- Expiry Management
- Reorder Recommendation
- Reports / Stock Card
- Audit Log
- Admin Settings

## Database RPC Included

- `receive_stock()`
- `issue_stock()`
- `adjust_stock()`
- `transfer_stock()`
- `create_stock_count_session()`
- `approve_stock_count()`
- `search_items()`
- `get_dashboard_summary()`
- `get_stock_card()`
- `calculate_reorder_recommendation()`

## Notes

This package is designed as a stable starting production codebase. Before hospital production use, validate RLS with real users, review workflow approval thresholds, and perform user acceptance testing with actual stock scenarios.
