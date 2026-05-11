-- 07 seed.sql
insert into public.roles(role_code, role_name, description) values
('super_admin','Super Admin','Full access'),
('inventory_manager','Inventory Manager','Manage inventory, approve and report'),
('inventory_staff','Inventory Staff','Receive, issue, transfer own warehouse'),
('pharmacist_staff','Pharmacist Staff','Pharmacy inventory staff'),
('department_user','Department User','Request and view own history'),
('auditor','Auditor','Read-only audit and reports'),
('viewer','Viewer','Read-only dashboard and reports')
on conflict(role_code) do update set role_name=excluded.role_name, description=excluded.description;

insert into public.permissions(permission_code, permission_name, module, action) values
('dashboard.view','View dashboard','dashboard','view'),
('items.manage','Manage items','items','manage'),
('stock.receive','Receive stock','stock','receive'),
('stock.issue','Issue stock','stock','issue'),
('stock.adjust','Adjust stock','stock','adjust'),
('stock.transfer','Transfer stock','stock','transfer'),
('stock.count','Stock count','stock','count'),
('reports.view','View reports','reports','view'),
('audit.view','View audit log','audit','view'),
('admin.manage','Admin settings','admin','manage')
on conflict(permission_code) do nothing;

insert into public.role_permissions(role_id, permission_id)
select r.id, p.id from public.roles r cross join public.permissions p
where r.role_code in ('super_admin','inventory_manager')
on conflict do nothing;

insert into public.role_permissions(role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.permission_code in ('dashboard.view','stock.receive','stock.issue','stock.transfer','reports.view')
where r.role_code in ('inventory_staff','pharmacist_staff')
on conflict do nothing;

insert into public.role_permissions(role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.permission_code in ('dashboard.view','reports.view','audit.view')
where r.role_code = 'auditor'
on conflict do nothing;

insert into public.role_permissions(role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.permission_code in ('dashboard.view','reports.view')
where r.role_code = 'viewer'
on conflict do nothing;

insert into public.departments(department_code, department_name) values
('PHARM','Pharmacy'),('CHEMO','IV Chemo'),('OPD','OPD'),('IPD','IPD')
on conflict(department_code) do nothing;

insert into public.warehouses(warehouse_code, warehouse_name, department_id)
select 'MAIN','Main Pharmacy Store', id from public.departments where department_code='PHARM'
on conflict(warehouse_code) do nothing;

insert into public.warehouses(warehouse_code, warehouse_name, department_id)
select 'CHEMO','IV Chemo Stock Room', id from public.departments where department_code='CHEMO'
on conflict(warehouse_code) do nothing;

insert into public.locations(warehouse_id, location_code, location_name, shelf, bin)
select w.id, 'GEN', 'General shelf', 'GEN', '01' from public.warehouses w
on conflict(warehouse_id, location_code) do nothing;

insert into public.units(unit_code, unit_name) values
('TAB','Tablet'),('CAP','Capsule'),('VIA','Vial'),('AMP','Ampoule'),('BOT','Bottle'),('BOX','Box'),('PCS','Piece')
on conflict(unit_code) do nothing;

insert into public.categories(category_code, category_name) values
('MED','Medication'),('SUPPLY','Medical Supply'),('HIGH_ALERT','High Alert Drug'),('CONTROLLED','Controlled Item')
on conflict(category_code) do nothing;

insert into public.app_settings(key, value, description) values
('near_expiry_days','{"days":90}'::jsonb,'Default near expiry threshold'),
('high_value_adjustment_threshold','{"amount":10000}'::jsonb,'Require approval threshold for adjustment')
on conflict(key) do update set value=excluded.value, description=excluded.description, updated_at=now();

-- First admin user setup after creating user in Supabase Auth:
-- update public.profiles
-- set role_id=(select id from public.roles where role_code='super_admin'), is_active=true, default_warehouse_id=(select id from public.warehouses where warehouse_code='MAIN')
-- where email='your-admin-email@hospital.com';
-- insert into public.user_warehouse_access(user_id, warehouse_id, can_receive, can_issue, can_adjust, can_transfer)
-- select id, (select id from public.warehouses where warehouse_code='MAIN'), true, true, true, true from public.profiles where email='your-admin-email@hospital.com'
-- on conflict do nothing;
