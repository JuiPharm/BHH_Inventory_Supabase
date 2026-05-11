# AI Rules Summary for BHH Inventory

- Supabase PostgreSQL is the source of truth.
- Frontend is React + Vite static app deployable to Netlify/GitHub Pages.
- Use Supabase Auth and RLS.
- Use SQL RPC for stock movement.
- Never expose service_role key in frontend.
- Never update stock_balances directly from frontend.
- Use FEFO for expiring lots.
- Log all stock movements and master-data changes.
- Keep UI hospital-grade, clean, premium, responsive.
- Use pagination and async search.
- Do not use Google Sheets, Apps Script, JSONP, or CORS workaround as backend.
