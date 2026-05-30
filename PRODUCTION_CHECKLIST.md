# Production Checklist

## Security

- [ ] No `service_role` key in frontend or Netlify variables
- [ ] RLS enabled on all public tables
- [ ] RPC validates active user and warehouse permission
- [ ] `stock_balances` direct writes are blocked
- [ ] Audit logs cannot be deleted from frontend
- [ ] Supabase Auth redirect URLs are correct

## Database

- [ ] All foreign keys are valid
- [ ] Indexes exist for search/report columns
- [ ] Dashboard queries are acceptable with production data volume
- [ ] **Automated Backups Setup:** Ensure Supabase PITR (Point-in-Time Recovery) is enabled for production projects.
- [ ] **Manual Backups:** Set up a cron job to run `pg_dump -d "$DATABASE_URL" -Fc -f backup.dump` for off-site backup.
- [ ] **Restore Test:** Successfully perform a full database restore in a staging environment.
## Workflow

- [ ] Receive workflow approved by pharmacy/inventory team
- [ ] Issue workflow approved
- [ ] FEFO rule accepted
- [ ] Adjustment approval threshold configured
- [ ] Stock count workflow tested

## UX

- [ ] Loading state visible
- [ ] Error message is readable
- [ ] Toast notification works
- [ ] Mobile/tablet display acceptable
- [ ] Search does not preload all items
- [ ] Print/export output checked

## Operations

- [ ] Admin user created
- [ ] Roles assigned
- [ ] Warehouse access assigned
- [ ] User training completed
- [ ] SOP written
- [ ] Go-live support plan prepared
