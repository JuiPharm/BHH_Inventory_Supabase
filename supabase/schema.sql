-- BHH Inventory Management System
-- 01 schema.sql
-- Run in Supabase SQL Editor before triggers/functions/RLS.

create extension if not exists pgcrypto;
create extension if not exists citext;
create extension if not exists pg_trgm;

create table if not exists public.roles (
  id uuid primary key default gen_random_uuid(),
  role_code text not null unique,
  role_name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.permissions (
  id uuid primary key default gen_random_uuid(),
  permission_code text not null unique,
  permission_name text not null,
  module text not null,
  action text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

create table if not exists public.departments (
  id uuid primary key default gen_random_uuid(),
  department_code text not null unique,
  department_name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.warehouses (
  id uuid primary key default gen_random_uuid(),
  warehouse_code text not null unique,
  warehouse_name text not null,
  department_id uuid references public.departments(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email citext,
  role_id uuid references public.roles(id),
  department_id uuid references public.departments(id),
  default_warehouse_id uuid references public.warehouses(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_warehouse_access (
  user_id uuid not null references public.profiles(id) on delete cascade,
  warehouse_id uuid not null references public.warehouses(id) on delete cascade,
  can_receive boolean not null default true,
  can_issue boolean not null default true,
  can_adjust boolean not null default false,
  can_transfer boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (user_id, warehouse_id)
);

create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  warehouse_id uuid not null references public.warehouses(id),
  location_code text not null,
  location_name text not null,
  shelf text,
  bin text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (warehouse_id, location_code)
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  category_code text not null unique,
  category_name text not null,
  parent_id uuid references public.categories(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.units (
  id uuid primary key default gen_random_uuid(),
  unit_code text not null unique,
  unit_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  supplier_code text not null unique,
  supplier_name text not null,
  contact_name text,
  phone text,
  email citext,
  address text,
  lead_time_days integer not null default 0 check (lead_time_days >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  item_code text not null unique,
  barcode text,
  item_name text not null,
  generic_name text,
  brand_name text,
  category_id uuid references public.categories(id),
  unit_id uuid references public.units(id),
  pack_size text default '1',
  min_stock numeric(14,3) not null default 0 check (min_stock >= 0),
  max_stock numeric(14,3) not null default 0 check (max_stock >= 0),
  reorder_point numeric(14,3) not null default 0 check (reorder_point >= 0),
  safety_stock numeric(14,3) not null default 0 check (safety_stock >= 0),
  lead_time_days integer not null default 0 check (lead_time_days >= 0),
  average_monthly_usage numeric(14,3) not null default 0 check (average_monthly_usage >= 0),
  storage_condition text,
  image_url text,
  is_lot_tracked boolean not null default true,
  is_expiry_tracked boolean not null default true,
  is_controlled boolean not null default false,
  is_high_alert boolean not null default false,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.item_suppliers (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id),
  supplier_id uuid not null references public.suppliers(id),
  supplier_item_code text,
  last_unit_cost numeric(14,4) not null default 0 check (last_unit_cost >= 0),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(item_id, supplier_id)
);

create table if not exists public.stock_lots (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id),
  warehouse_id uuid not null references public.warehouses(id),
  location_id uuid references public.locations(id),
  lot_no text,
  expiry_date date,
  mfg_date date,
  unit_cost numeric(14,4) not null default 0 check (unit_cost >= 0),
  received_date date not null default current_date,
  supplier_id uuid references public.suppliers(id),
  status text not null default 'available' check (status in ('available','expired','quarantine','damaged','disposed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.stock_balances (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id),
  warehouse_id uuid not null references public.warehouses(id),
  location_id uuid references public.locations(id),
  lot_id uuid references public.stock_lots(id),
  qty_on_hand numeric(14,3) not null default 0,
  qty_reserved numeric(14,3) not null default 0,
  qty_available numeric(14,3) generated always as (qty_on_hand - qty_reserved) stored,
  unit_cost numeric(14,4) not null default 0 check (unit_cost >= 0),
  updated_at timestamptz not null default now(),
  check (qty_on_hand >= 0),
  check (qty_reserved >= 0),
  check (qty_on_hand >= qty_reserved)
);

create table if not exists public.stock_transactions (
  id uuid primary key default gen_random_uuid(),
  transaction_no text not null unique,
  transaction_type text not null check (transaction_type in ('RECEIVE','ISSUE','ADJUST','TRANSFER_OUT','TRANSFER_IN','COUNT_ADJUST')),
  item_id uuid not null references public.items(id),
  warehouse_id uuid not null references public.warehouses(id),
  location_id uuid references public.locations(id),
  lot_id uuid references public.stock_lots(id),
  qty_in numeric(14,3) not null default 0 check (qty_in >= 0),
  qty_out numeric(14,3) not null default 0 check (qty_out >= 0),
  balance_after numeric(14,3) not null default 0,
  unit_cost numeric(14,4) not null default 0 check (unit_cost >= 0),
  total_cost numeric(14,4) generated always as ((qty_in + qty_out) * unit_cost) stored,
  reference_type text,
  reference_id uuid,
  reason text,
  remarks text,
  performed_by uuid references public.profiles(id),
  performed_at timestamptz not null default now()
);

create table if not exists public.receives (
  id uuid primary key default gen_random_uuid(),
  receive_no text not null unique,
  supplier_id uuid references public.suppliers(id),
  warehouse_id uuid not null references public.warehouses(id),
  invoice_no text,
  receive_date date not null default current_date,
  status text not null default 'posted' check (status in ('draft','posted','cancelled')),
  remarks text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.receive_items (
  id uuid primary key default gen_random_uuid(),
  receive_id uuid not null references public.receives(id) on delete cascade,
  item_id uuid not null references public.items(id),
  location_id uuid references public.locations(id),
  lot_id uuid references public.stock_lots(id),
  lot_no text,
  expiry_date date,
  mfg_date date,
  qty numeric(14,3) not null check (qty > 0),
  unit_cost numeric(14,4) not null default 0 check (unit_cost >= 0)
);

create table if not exists public.issues (
  id uuid primary key default gen_random_uuid(),
  issue_no text not null unique,
  issue_to_department_id uuid references public.departments(id),
  warehouse_id uuid not null references public.warehouses(id),
  requester_name text,
  issue_date date not null default current_date,
  status text not null default 'posted' check (status in ('draft','posted','cancelled')),
  remarks text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.issue_items (
  id uuid primary key default gen_random_uuid(),
  issue_id uuid not null references public.issues(id) on delete cascade,
  item_id uuid not null references public.items(id),
  lot_id uuid references public.stock_lots(id),
  qty numeric(14,3) not null check (qty > 0),
  unit_cost numeric(14,4) not null default 0 check (unit_cost >= 0),
  reason text
);

create table if not exists public.adjustments (
  id uuid primary key default gen_random_uuid(),
  adjustment_no text not null unique,
  warehouse_id uuid not null references public.warehouses(id),
  reason text not null,
  status text not null default 'posted' check (status in ('draft','pending_approval','posted','rejected','cancelled')),
  remarks text,
  approved_by uuid references public.profiles(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.adjustment_items (
  id uuid primary key default gen_random_uuid(),
  adjustment_id uuid not null references public.adjustments(id) on delete cascade,
  item_id uuid not null references public.items(id),
  lot_id uuid not null references public.stock_lots(id),
  qty_before numeric(14,3) not null,
  qty_adjust numeric(14,3) not null,
  qty_after numeric(14,3) not null,
  reason text not null
);

create table if not exists public.transfers (
  id uuid primary key default gen_random_uuid(),
  transfer_no text not null unique,
  from_warehouse_id uuid not null references public.warehouses(id),
  to_warehouse_id uuid not null references public.warehouses(id),
  status text not null default 'received' check (status in ('draft','pending','received','cancelled')),
  remarks text,
  requested_by uuid references public.profiles(id),
  approved_by uuid references public.profiles(id),
  received_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  received_at timestamptz,
  check (from_warehouse_id <> to_warehouse_id)
);

create table if not exists public.transfer_items (
  id uuid primary key default gen_random_uuid(),
  transfer_id uuid not null references public.transfers(id) on delete cascade,
  item_id uuid not null references public.items(id),
  lot_id uuid not null references public.stock_lots(id),
  qty numeric(14,3) not null check (qty > 0)
);

create table if not exists public.stock_counts (
  id uuid primary key default gen_random_uuid(),
  count_no text not null unique,
  warehouse_id uuid not null references public.warehouses(id),
  count_date date not null default current_date,
  status text not null default 'open' check (status in ('open','counting','approved','cancelled')),
  created_by uuid references public.profiles(id),
  approved_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  approved_at timestamptz
);

create table if not exists public.stock_count_items (
  id uuid primary key default gen_random_uuid(),
  stock_count_id uuid not null references public.stock_counts(id) on delete cascade,
  item_id uuid not null references public.items(id),
  lot_id uuid references public.stock_lots(id),
  system_qty numeric(14,3) not null default 0,
  counted_qty numeric(14,3),
  variance_qty numeric(14,3) generated always as (coalesce(counted_qty, system_qty) - system_qty) stored,
  variance_value numeric(14,4),
  remarks text
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  table_name text not null,
  record_id text not null,
  action text not null check (action in ('INSERT','UPDATE','DELETE')),
  old_data jsonb,
  new_data jsonb,
  changed_by uuid,
  changed_at timestamptz not null default now(),
  ip_address text,
  user_agent text
);

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  description text,
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  notification_type text not null,
  title text not null,
  message text not null,
  severity text not null default 'info' check (severity in ('info','success','warning','critical')),
  target_role uuid references public.roles(id),
  target_user uuid references public.profiles(id),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_items_item_code on public.items(item_code);
create index if not exists idx_items_barcode on public.items(barcode);
create index if not exists idx_items_name_trgm on public.items using gin (item_name gin_trgm_ops);
create index if not exists idx_items_generic_trgm on public.items using gin (generic_name gin_trgm_ops);

create unique index if not exists ux_stock_lots_identity on public.stock_lots(item_id, warehouse_id, coalesce(lot_no,''), coalesce(expiry_date, date '9999-12-31'), unit_cost);
create unique index if not exists ux_stock_balances_identity on public.stock_balances(item_id, warehouse_id, coalesce(location_id, '00000000-0000-0000-0000-000000000000'::uuid), coalesce(lot_id, '00000000-0000-0000-0000-000000000000'::uuid));
create index if not exists idx_stock_balances_item on public.stock_balances(item_id);
create index if not exists idx_stock_balances_warehouse on public.stock_balances(warehouse_id);
create index if not exists idx_stock_balances_lot on public.stock_balances(lot_id);
create index if not exists idx_stock_lots_expiry on public.stock_lots(expiry_date);
create index if not exists idx_stock_lots_lot_no on public.stock_lots(lot_no);
create index if not exists idx_transactions_item on public.stock_transactions(item_id);
create index if not exists idx_transactions_warehouse on public.stock_transactions(warehouse_id);
create index if not exists idx_transactions_performed_at on public.stock_transactions(performed_at desc);
create index if not exists idx_transactions_type on public.stock_transactions(transaction_type);
create index if not exists idx_receives_date on public.receives(receive_date desc);
create index if not exists idx_issues_date on public.issues(issue_date desc);
create index if not exists idx_audit_changed_at on public.audit_logs(changed_at desc);
