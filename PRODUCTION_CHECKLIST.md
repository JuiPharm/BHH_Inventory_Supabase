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
- [ ] Backup plan exists
- [ ] Restore test completed

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
