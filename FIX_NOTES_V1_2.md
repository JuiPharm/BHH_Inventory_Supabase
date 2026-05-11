# BHH Inventory Netlify v1.2 Fix Notes

## Fixed issues

1. Supabase RPC schema cache error
   - `public.get_dashboard_summary(p_warehouse_id)`
   - `public.calculate_reorder_recommendation(p_warehouse_id)`

2. Expiry view error
   - Recreated `public.near_expiry_view`
   - Added `days_to_expiry`

3. Issue Stock destination department
   - Added department dropdown in frontend Issue page
   - Supports OPD Pharmacy, IPD Pharmacy, IV Chemo

4. Requester source
   - Requester is now derived from current login profile/email
   - Frontend shows it as read-only
   - SQL RPC also defaults to current profile/email if frontend sends blank

5. Dashboard and Stock Balance
   - Dashboard RPC recreated with warehouse parameter
   - Current stock view recreated with warehouse-aware view columns

## Required SQL for existing Supabase projects

Run this file in Supabase SQL Editor after uploading/deploying frontend:

```txt
supabase/hotfix_netlify_v1_2.sql
```

Then reload the web app and log in again.

## Netlify deploy

Use normal Netlify settings:

```txt
Build command: npm run build
Publish directory: dist
Base directory: blank
```

Environment variables:

```txt
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-public-key
VITE_APP_NAME=BHH Inventory Management System
VITE_BASE_PATH=/
```
