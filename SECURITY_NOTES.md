# Security Notes

1. Frontend uses only Supabase anon key.
2. Supabase anon key is public by design, but RLS must be strict.
3. Do not put service_role key in `.env`, Netlify, GitHub, or frontend.
4. Stock movement is only through RPC functions.
5. `stock_balances` is protected by RLS and trigger.
6. Audit logs are read-only for normal users.
7. Master data with transactions should be deactivated, not hard deleted.
8. For production, consider using Supabase Point-in-Time Recovery if available on your plan.
