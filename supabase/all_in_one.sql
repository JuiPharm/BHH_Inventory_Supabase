

-- =========================================================
-- schema.sql
-- =========================================================
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


-- =========================================================
-- triggers.sql
-- =========================================================
-- 02 triggers.sql
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.set_current_user_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if to_jsonb(new) ? 'created_by' and new.created_by is null then
      new.created_by = auth.uid();
    end if;
    if to_jsonb(new) ? 'updated_by' and new.updated_by is null then
      new.updated_by = auth.uid();
    end if;
  elsif tg_op = 'UPDATE' then
    if to_jsonb(new) ? 'updated_by' then
      new.updated_by = auth.uid();
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.audit_row_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_record_id text;
begin
  if tg_op = 'DELETE' then
    v_record_id := coalesce(to_jsonb(old)->>'id', to_jsonb(old)->>'key');
    insert into public.audit_logs(table_name, record_id, action, old_data, new_data, changed_by)
    values (tg_table_name, v_record_id, tg_op, to_jsonb(old), null, auth.uid());
    return old;
  elsif tg_op = 'UPDATE' then
    v_record_id := coalesce(to_jsonb(new)->>'id', to_jsonb(new)->>'key');
    insert into public.audit_logs(table_name, record_id, action, old_data, new_data, changed_by)
    values (tg_table_name, v_record_id, tg_op, to_jsonb(old), to_jsonb(new), auth.uid());
    return new;
  else
    v_record_id := coalesce(to_jsonb(new)->>'id', to_jsonb(new)->>'key');
    insert into public.audit_logs(table_name, record_id, action, old_data, new_data, changed_by)
    values (tg_table_name, v_record_id, tg_op, null, to_jsonb(new), auth.uid());
    return new;
  end if;
end;
$$;

create or replace function public.protect_stock_balances_direct_write()
returns trigger
language plpgsql
as $$
begin
  if current_setting('app.stock_rpc', true) <> 'on' then
    raise exception 'Direct stock balance modification is blocked. Use RPC stock movement functions only.';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['roles','departments','warehouses','locations','categories','units','suppliers','items','item_suppliers','stock_lots'] loop
    execute format('drop trigger if exists trg_%I_updated_at on public.%I', t, t);
    execute format('create trigger trg_%I_updated_at before update on public.%I for each row execute function public.set_updated_at()', t, t);
  end loop;
end $$;

drop trigger if exists trg_items_user_columns on public.items;
create trigger trg_items_user_columns before insert or update on public.items for each row execute function public.set_current_user_columns();

do $$
declare t text;
begin
  foreach t in array array['profiles','roles','departments','warehouses','locations','categories','units','suppliers','items','item_suppliers','receives','issues','adjustments','transfers','stock_counts','app_settings'] loop
    execute format('drop trigger if exists trg_%I_audit on public.%I', t, t);
    execute format('create trigger trg_%I_audit after insert or update or delete on public.%I for each row execute function public.audit_row_changes()', t, t);
  end loop;
end $$;



create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles(id, email, full_name, is_active)
  values(new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', new.email), true)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_create_profile on auth.users;
create trigger on_auth_user_created_create_profile
after insert on auth.users
for each row execute function public.handle_new_user_profile();

drop trigger if exists trg_stock_balances_protect on public.stock_balances;
create trigger trg_stock_balances_protect before insert or update or delete on public.stock_balances for each row execute function public.protect_stock_balances_direct_write();


-- =========================================================
-- views.sql
-- =========================================================
-- 03 views.sql
create or replace view public.current_stock_view with (security_invoker = true) as
select
  sb.id as balance_id,
  sb.item_id,
  i.item_code,
  i.item_name,
  i.generic_name,
  i.brand_name,
  c.category_name,
  u.unit_name,
  sb.warehouse_id,
  w.warehouse_name,
  sb.location_id,
  l.location_name,
  sb.lot_id,
  sl.lot_no,
  sl.expiry_date,
  sb.qty_on_hand,
  sb.qty_reserved,
  sb.qty_available,
  sb.unit_cost,
  (sb.qty_available * sb.unit_cost) as total_value,
  case when sb.qty_available <= 0 then 'out_of_stock'
       when sb.qty_available <= greatest(i.reorder_point, i.min_stock) then 'low_stock'
       else 'normal' end as stock_status,
  case when i.is_expiry_tracked is false then 'not_tracked'
       when sl.expiry_date is null then 'normal'
       when sl.expiry_date < current_date then 'expired'
       when sl.expiry_date <= current_date + interval '90 days' then 'near_expiry'
       else 'normal' end as expiry_status
from public.stock_balances sb
join public.items i on i.id = sb.item_id
join public.warehouses w on w.id = sb.warehouse_id
left join public.locations l on l.id = sb.location_id
left join public.stock_lots sl on sl.id = sb.lot_id
left join public.categories c on c.id = i.category_id
left join public.units u on u.id = i.unit_id;

create or replace view public.low_stock_view with (security_invoker = true) as
select * from public.current_stock_view where stock_status in ('low_stock','out_of_stock');

create or replace view public.near_expiry_view with (security_invoker = true) as
select
  csv.lot_id,
  csv.item_id,
  csv.item_code,
  csv.item_name,
  csv.warehouse_id,
  csv.warehouse_name,
  csv.lot_no,
  csv.expiry_date,
  (csv.expiry_date - current_date) as days_to_expiry,
  csv.qty_available,
  csv.expiry_status
from public.current_stock_view csv
where csv.expiry_status in ('expired','near_expiry');

create or replace view public.inventory_valuation_view with (security_invoker = true) as
select category_name, warehouse_id, warehouse_name, sum(total_value) total_value, count(distinct item_id) sku_count
from public.current_stock_view
group by category_name, warehouse_id, warehouse_name;

create or replace view public.stock_movement_view with (security_invoker = true) as
select st.*, i.item_code, i.item_name, w.warehouse_name, sl.lot_no
from public.stock_transactions st
join public.items i on i.id = st.item_id
join public.warehouses w on w.id = st.warehouse_id
left join public.stock_lots sl on sl.id = st.lot_id;


-- =========================================================
-- functions.sql
-- =========================================================
-- 04 functions.sql

create or replace function public.current_role_code()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select r.role_code
  from public.profiles p
  join public.roles r on r.id = p.role_id
  where p.id = auth.uid() and p.is_active = true
  limit 1;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_role_code() in ('super_admin','inventory_manager'), false);
$$;

create or replace function public.is_readonly_role()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_role_code() in ('viewer','auditor'), false);
$$;

create or replace function public.user_has_warehouse(p_warehouse_id uuid, p_action text default 'read')
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.is_admin(), false)
    or exists (
      select 1 from public.user_warehouse_access uwa
      where uwa.user_id = auth.uid()
        and uwa.warehouse_id = p_warehouse_id
        and case p_action
          when 'receive' then uwa.can_receive
          when 'issue' then uwa.can_issue
          when 'adjust' then uwa.can_adjust
          when 'transfer' then uwa.can_transfer
          else true
        end
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.default_warehouse_id = p_warehouse_id and p.is_active = true
    );
$$;

create or replace function public.assert_active_user()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Login required'; end if;
  if not exists (select 1 from public.profiles where id = auth.uid() and is_active = true) then
    raise exception 'User is inactive or profile is missing';
  end if;
end;
$$;

create or replace function public.assert_warehouse_permission(p_warehouse_id uuid, p_action text)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.assert_active_user();
  if public.is_readonly_role() then raise exception 'Read-only role cannot perform this action'; end if;
  if not public.user_has_warehouse(p_warehouse_id, p_action) then
    raise exception 'Unauthorized warehouse access';
  end if;
end;
$$;

create or replace function public.gen_doc_no(p_prefix text)
returns text
language sql
volatile
as $$
  select p_prefix || to_char(now(), 'YYYYMMDDHH24MISS') || '-' || lpad((floor(random()*10000))::text, 4, '0');
$$;

create or replace function public.search_items(p_keyword text, p_limit integer default 20)
returns table(
  id uuid, item_code text, barcode text, item_name text, generic_name text, brand_name text,
  unit_name text, is_high_alert boolean, is_controlled boolean, is_expiry_tracked boolean, is_lot_tracked boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select i.id, i.item_code, i.barcode, i.item_name, i.generic_name, i.brand_name, u.unit_name,
         i.is_high_alert, i.is_controlled, i.is_expiry_tracked, i.is_lot_tracked
  from public.items i
  left join public.units u on u.id = i.unit_id
  where i.is_active = true
    and (
      p_keyword is null or p_keyword = '' or
      i.item_code ilike '%' || p_keyword || '%' or
      coalesce(i.barcode,'') ilike '%' || p_keyword || '%' or
      i.item_name ilike '%' || p_keyword || '%' or
      coalesce(i.generic_name,'') ilike '%' || p_keyword || '%' or
      coalesce(i.brand_name,'') ilike '%' || p_keyword || '%'
    )
  order by case when i.item_code = p_keyword then 0 else 1 end, i.item_name
  limit greatest(1, least(coalesce(p_limit,20),50));
$$;

create or replace function public.receive_stock(
  p_supplier_id uuid,
  p_warehouse_id uuid,
  p_invoice_no text,
  p_receive_date date,
  p_remarks text,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_receive_id uuid;
  v_receive_no text := public.gen_doc_no('RCV');
  v_line jsonb;
  v_item public.items%rowtype;
  v_lot_id uuid;
  v_balance_id uuid;
  v_qty numeric;
  v_unit_cost numeric;
  v_lot_no text;
  v_expiry date;
  v_mfg date;
  v_location uuid;
  v_balance_after numeric;
begin
  perform public.assert_warehouse_permission(p_warehouse_id, 'receive');
  if p_items is null or jsonb_array_length(p_items) = 0 then raise exception 'Receive items required'; end if;
  perform set_config('app.stock_rpc','on', true);

  insert into public.receives(receive_no, supplier_id, warehouse_id, invoice_no, receive_date, remarks, created_by)
  values(v_receive_no, p_supplier_id, p_warehouse_id, nullif(p_invoice_no,''), coalesce(p_receive_date,current_date), p_remarks, auth.uid())
  returning id into v_receive_id;

  for v_line in select * from jsonb_array_elements(p_items) loop
    select * into v_item from public.items where id = (v_line->>'item_id')::uuid and is_active = true;
    if not found then raise exception 'Item not found or inactive'; end if;

    v_qty := (v_line->>'qty')::numeric;
    v_unit_cost := coalesce((v_line->>'unit_cost')::numeric,0);
    v_lot_no := nullif(v_line->>'lot_no','');
    v_expiry := nullif(v_line->>'expiry_date','')::date;
    v_mfg := nullif(v_line->>'mfg_date','')::date;
    v_location := nullif(v_line->>'location_id','')::uuid;

    if v_qty <= 0 then raise exception 'Receive quantity must be greater than zero'; end if;
    if v_unit_cost < 0 then raise exception 'Unit cost cannot be negative'; end if;
    if v_item.is_expiry_tracked and v_expiry is null then raise exception 'Expiry date is required for %', v_item.item_name; end if;
    if v_item.is_lot_tracked and v_lot_no is null then raise exception 'Lot number is required for %', v_item.item_name; end if;

    select id into v_lot_id
    from public.stock_lots
    where item_id = v_item.id and warehouse_id = p_warehouse_id
      and coalesce(lot_no,'') = coalesce(v_lot_no,'')
      and coalesce(expiry_date, date '9999-12-31') = coalesce(v_expiry, date '9999-12-31')
      and unit_cost = v_unit_cost
    limit 1;

    if v_lot_id is null then
      insert into public.stock_lots(item_id, warehouse_id, location_id, lot_no, expiry_date, mfg_date, unit_cost, received_date, supplier_id)
      values(v_item.id, p_warehouse_id, v_location, v_lot_no, v_expiry, v_mfg, v_unit_cost, coalesce(p_receive_date,current_date), p_supplier_id)
      returning id into v_lot_id;
    end if;

    select id into v_balance_id from public.stock_balances
    where item_id = v_item.id and warehouse_id = p_warehouse_id
      and coalesce(location_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(v_location, '00000000-0000-0000-0000-000000000000'::uuid)
      and lot_id = v_lot_id
    limit 1;

    if v_balance_id is null then
      insert into public.stock_balances(item_id, warehouse_id, location_id, lot_id, qty_on_hand, qty_reserved, unit_cost)
      values(v_item.id, p_warehouse_id, v_location, v_lot_id, v_qty, 0, v_unit_cost)
      returning id, qty_on_hand into v_balance_id, v_balance_after;
    else
      update public.stock_balances
      set qty_on_hand = qty_on_hand + v_qty, unit_cost = v_unit_cost, updated_at = now()
      where id = v_balance_id
      returning qty_on_hand into v_balance_after;
    end if;

    insert into public.receive_items(receive_id, item_id, location_id, lot_id, lot_no, expiry_date, mfg_date, qty, unit_cost)
    values(v_receive_id, v_item.id, v_location, v_lot_id, v_lot_no, v_expiry, v_mfg, v_qty, v_unit_cost);

    insert into public.stock_transactions(transaction_no, transaction_type, item_id, warehouse_id, location_id, lot_id, qty_in, qty_out, balance_after, unit_cost, reference_type, reference_id, remarks, performed_by)
    values(public.gen_doc_no('TRN'), 'RECEIVE', v_item.id, p_warehouse_id, v_location, v_lot_id, v_qty, 0, v_balance_after, v_unit_cost, 'receives', v_receive_id, p_remarks, auth.uid());
  end loop;
  return jsonb_build_object('receive_id', v_receive_id, 'receive_no', v_receive_no);
end;
$$;

create or replace function public.issue_stock(
  p_warehouse_id uuid,
  p_issue_to_department_id uuid,
  p_requester_name text,
  p_issue_date date,
  p_remarks text,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_issue_id uuid;
  v_issue_no text := public.gen_doc_no('ISS');
  v_line jsonb;
  v_item public.items%rowtype;
  v_requested numeric;
  v_remaining numeric;
  v_reason text;
  v_lot_filter uuid;
  v_bal record;
  v_take numeric;
  v_balance_after numeric;
begin
  perform public.assert_warehouse_permission(p_warehouse_id, 'issue');
  if p_items is null or jsonb_array_length(p_items) = 0 then raise exception 'Issue items required'; end if;
  perform set_config('app.stock_rpc','on', true);

  insert into public.issues(issue_no, issue_to_department_id, warehouse_id, requester_name, issue_date, remarks, created_by)
  values(v_issue_no, p_issue_to_department_id, p_warehouse_id, nullif(p_requester_name,''), coalesce(p_issue_date,current_date), p_remarks, auth.uid())
  returning id into v_issue_id;

  for v_line in select * from jsonb_array_elements(p_items) loop
    select * into v_item from public.items where id = (v_line->>'item_id')::uuid and is_active = true;
    if not found then raise exception 'Item not found or inactive'; end if;
    v_requested := (v_line->>'qty')::numeric;
    v_remaining := v_requested;
    v_reason := nullif(v_line->>'reason','');
    v_lot_filter := nullif(v_line->>'lot_id','')::uuid;
    if v_requested <= 0 then raise exception 'Issue quantity must be greater than zero'; end if;
    if (v_item.is_controlled or v_item.is_high_alert) and coalesce(v_reason,'') = '' then raise exception 'Reason is required for controlled/high-alert item %', v_item.item_name; end if;

    for v_bal in
      select sb.*, sl.expiry_date, sl.status
      from public.stock_balances sb
      left join public.stock_lots sl on sl.id = sb.lot_id
      where sb.item_id = v_item.id and sb.warehouse_id = p_warehouse_id
        and (v_lot_filter is null or sb.lot_id = v_lot_filter)
        and sb.qty_available > 0
        and coalesce(sl.status,'available') = 'available'
        and (sl.expiry_date is null or sl.expiry_date >= current_date)
      order by sl.expiry_date nulls last, sb.updated_at
    loop
      exit when v_remaining <= 0;
      v_take := least(v_remaining, v_bal.qty_available);
      update public.stock_balances set qty_on_hand = qty_on_hand - v_take, updated_at = now() where id = v_bal.id returning qty_on_hand into v_balance_after;
      insert into public.issue_items(issue_id, item_id, lot_id, qty, unit_cost, reason) values(v_issue_id, v_item.id, v_bal.lot_id, v_take, v_bal.unit_cost, v_reason);
      insert into public.stock_transactions(transaction_no, transaction_type, item_id, warehouse_id, location_id, lot_id, qty_in, qty_out, balance_after, unit_cost, reference_type, reference_id, reason, remarks, performed_by)
      values(public.gen_doc_no('TRN'), 'ISSUE', v_item.id, p_warehouse_id, v_bal.location_id, v_bal.lot_id, 0, v_take, v_balance_after, v_bal.unit_cost, 'issues', v_issue_id, v_reason, p_remarks, auth.uid());
      v_remaining := v_remaining - v_take;
    end loop;

    if v_remaining > 0 then raise exception 'Insufficient available stock for %', v_item.item_name; end if;
  end loop;
  return jsonb_build_object('issue_id', v_issue_id, 'issue_no', v_issue_no);
end;
$$;

create or replace function public.adjust_stock(p_warehouse_id uuid, p_reason text, p_remarks text, p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_adjustment_id uuid; v_adjustment_no text := public.gen_doc_no('ADJ'); v_line jsonb; v_bal record; v_qty_adjust numeric; v_after numeric; v_line_reason text;
begin
  perform public.assert_warehouse_permission(p_warehouse_id, 'adjust');
  if coalesce(p_reason,'') = '' then raise exception 'Adjustment reason is required'; end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then raise exception 'Adjustment items required'; end if;
  perform set_config('app.stock_rpc','on', true);
  insert into public.adjustments(adjustment_no, warehouse_id, reason, remarks, approved_by, created_by)
  values(v_adjustment_no, p_warehouse_id, p_reason, p_remarks, auth.uid(), auth.uid()) returning id into v_adjustment_id;
  for v_line in select * from jsonb_array_elements(p_items) loop
    v_qty_adjust := (v_line->>'qty_adjust')::numeric;
    v_line_reason := coalesce(nullif(v_line->>'reason',''), p_reason);
    select * into v_bal from public.stock_balances where warehouse_id=p_warehouse_id and item_id=(v_line->>'item_id')::uuid and lot_id=(v_line->>'lot_id')::uuid for update;
    if not found then raise exception 'Stock balance not found for adjustment'; end if;
    if v_bal.qty_on_hand + v_qty_adjust < 0 then raise exception 'Adjustment would make stock negative'; end if;
    update public.stock_balances set qty_on_hand = qty_on_hand + v_qty_adjust, updated_at=now() where id=v_bal.id returning qty_on_hand into v_after;
    insert into public.adjustment_items(adjustment_id,item_id,lot_id,qty_before,qty_adjust,qty_after,reason) values(v_adjustment_id,v_bal.item_id,v_bal.lot_id,v_bal.qty_on_hand,v_qty_adjust,v_after,v_line_reason);
    insert into public.stock_transactions(transaction_no,transaction_type,item_id,warehouse_id,location_id,lot_id,qty_in,qty_out,balance_after,unit_cost,reference_type,reference_id,reason,remarks,performed_by)
    values(public.gen_doc_no('TRN'),'ADJUST',v_bal.item_id,p_warehouse_id,v_bal.location_id,v_bal.lot_id,case when v_qty_adjust>0 then v_qty_adjust else 0 end,case when v_qty_adjust<0 then abs(v_qty_adjust) else 0 end,v_after,v_bal.unit_cost,'adjustments',v_adjustment_id,v_line_reason,p_remarks,auth.uid());
  end loop;
  return jsonb_build_object('adjustment_id', v_adjustment_id, 'adjustment_no', v_adjustment_no);
end;
$$;

create or replace function public.transfer_stock(p_from_warehouse_id uuid, p_to_warehouse_id uuid, p_remarks text, p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_transfer_id uuid; v_transfer_no text := public.gen_doc_no('TRF'); v_line jsonb; v_src record; v_dest_lot uuid; v_dest_bal uuid; v_qty numeric; v_src_after numeric; v_dest_after numeric;
begin
  if p_from_warehouse_id = p_to_warehouse_id then raise exception 'Source and destination warehouse must be different'; end if;
  perform public.assert_warehouse_permission(p_from_warehouse_id, 'transfer');
  perform public.assert_warehouse_permission(p_to_warehouse_id, 'transfer');
  if p_items is null or jsonb_array_length(p_items) = 0 then raise exception 'Transfer items required'; end if;
  perform set_config('app.stock_rpc','on', true);
  insert into public.transfers(transfer_no,from_warehouse_id,to_warehouse_id,status,remarks,requested_by,approved_by,received_by,received_at)
  values(v_transfer_no,p_from_warehouse_id,p_to_warehouse_id,'received',p_remarks,auth.uid(),auth.uid(),auth.uid(),now()) returning id into v_transfer_id;
  for v_line in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_line->>'qty')::numeric;
    if v_qty <= 0 then raise exception 'Transfer qty must be positive'; end if;
    select sb.*, sl.lot_no, sl.expiry_date, sl.mfg_date, sl.supplier_id, sl.status into v_src
    from public.stock_balances sb join public.stock_lots sl on sl.id=sb.lot_id
    where sb.warehouse_id=p_from_warehouse_id and sb.item_id=(v_line->>'item_id')::uuid and sb.lot_id=(v_line->>'lot_id')::uuid for update;
    if not found or v_src.qty_available < v_qty then raise exception 'Insufficient stock for transfer'; end if;
    update public.stock_balances set qty_on_hand=qty_on_hand-v_qty, updated_at=now() where id=v_src.id returning qty_on_hand into v_src_after;
    select id into v_dest_lot from public.stock_lots where item_id=v_src.item_id and warehouse_id=p_to_warehouse_id and coalesce(lot_no,'')=coalesce(v_src.lot_no,'') and coalesce(expiry_date,date '9999-12-31')=coalesce(v_src.expiry_date,date '9999-12-31') and unit_cost=v_src.unit_cost limit 1;
    if v_dest_lot is null then insert into public.stock_lots(item_id,warehouse_id,location_id,lot_no,expiry_date,mfg_date,unit_cost,received_date,supplier_id,status) values(v_src.item_id,p_to_warehouse_id,null,v_src.lot_no,v_src.expiry_date,v_src.mfg_date,v_src.unit_cost,current_date,v_src.supplier_id,v_src.status) returning id into v_dest_lot; end if;
    select id into v_dest_bal from public.stock_balances where item_id=v_src.item_id and warehouse_id=p_to_warehouse_id and lot_id=v_dest_lot limit 1;
    if v_dest_bal is null then insert into public.stock_balances(item_id,warehouse_id,location_id,lot_id,qty_on_hand,qty_reserved,unit_cost) values(v_src.item_id,p_to_warehouse_id,null,v_dest_lot,v_qty,0,v_src.unit_cost) returning id,qty_on_hand into v_dest_bal,v_dest_after; else update public.stock_balances set qty_on_hand=qty_on_hand+v_qty, updated_at=now() where id=v_dest_bal returning qty_on_hand into v_dest_after; end if;
    insert into public.transfer_items(transfer_id,item_id,lot_id,qty) values(v_transfer_id,v_src.item_id,v_src.lot_id,v_qty);
    insert into public.stock_transactions(transaction_no,transaction_type,item_id,warehouse_id,location_id,lot_id,qty_in,qty_out,balance_after,unit_cost,reference_type,reference_id,remarks,performed_by) values(public.gen_doc_no('TRN'),'TRANSFER_OUT',v_src.item_id,p_from_warehouse_id,v_src.location_id,v_src.lot_id,0,v_qty,v_src_after,v_src.unit_cost,'transfers',v_transfer_id,p_remarks,auth.uid());
    insert into public.stock_transactions(transaction_no,transaction_type,item_id,warehouse_id,location_id,lot_id,qty_in,qty_out,balance_after,unit_cost,reference_type,reference_id,remarks,performed_by) values(public.gen_doc_no('TRN'),'TRANSFER_IN',v_src.item_id,p_to_warehouse_id,null,v_dest_lot,v_qty,0,v_dest_after,v_src.unit_cost,'transfers',v_transfer_id,p_remarks,auth.uid());
  end loop;
  return jsonb_build_object('transfer_id', v_transfer_id, 'transfer_no', v_transfer_no);
end;
$$;

create or replace function public.create_stock_count_session(p_warehouse_id uuid, p_category_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_count_id uuid; v_count_no text := public.gen_doc_no('CNT');
begin
  perform public.assert_warehouse_permission(p_warehouse_id, 'adjust');
  insert into public.stock_counts(count_no, warehouse_id, created_by) values(v_count_no, p_warehouse_id, auth.uid()) returning id into v_count_id;
  insert into public.stock_count_items(stock_count_id,item_id,lot_id,system_qty,variance_value)
  select v_count_id, sb.item_id, sb.lot_id, sb.qty_on_hand, 0
  from public.stock_balances sb join public.items i on i.id=sb.item_id
  where sb.warehouse_id=p_warehouse_id and (p_category_id is null or i.category_id=p_category_id);
  return jsonb_build_object('stock_count_id', v_count_id, 'count_no', v_count_no);
end;
$$;

create or replace function public.approve_stock_count(p_stock_count_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_count public.stock_counts%rowtype; v_adjustment_id uuid; v_adjustment_no text := public.gen_doc_no('CADJ'); v_line record; v_after numeric;
begin
  select * into v_count from public.stock_counts where id=p_stock_count_id for update;
  if not found then raise exception 'Stock count not found'; end if;
  if v_count.status='approved' then raise exception 'Stock count already approved'; end if;
  perform public.assert_warehouse_permission(v_count.warehouse_id, 'adjust');
  perform set_config('app.stock_rpc','on', true);
  insert into public.adjustments(adjustment_no,warehouse_id,reason,status,approved_by,created_by) values(v_adjustment_no,v_count.warehouse_id,'Stock count variance','posted',auth.uid(),auth.uid()) returning id into v_adjustment_id;
  for v_line in select sci.*, sb.id balance_id, sb.location_id, sb.unit_cost, sb.qty_on_hand from public.stock_count_items sci join public.stock_balances sb on sb.item_id=sci.item_id and sb.lot_id=sci.lot_id and sb.warehouse_id=v_count.warehouse_id where sci.stock_count_id=p_stock_count_id and coalesce(sci.counted_qty,sci.system_qty) <> sci.system_qty loop
    if v_line.qty_on_hand + v_line.variance_qty < 0 then raise exception 'Count approval would make stock negative'; end if;
    update public.stock_balances set qty_on_hand=qty_on_hand+v_line.variance_qty, updated_at=now() where id=v_line.balance_id returning qty_on_hand into v_after;
    insert into public.adjustment_items(adjustment_id,item_id,lot_id,qty_before,qty_adjust,qty_after,reason) values(v_adjustment_id,v_line.item_id,v_line.lot_id,v_line.system_qty,v_line.variance_qty,v_after,'Stock count variance');
    insert into public.stock_transactions(transaction_no,transaction_type,item_id,warehouse_id,location_id,lot_id,qty_in,qty_out,balance_after,unit_cost,reference_type,reference_id,reason,performed_by) values(public.gen_doc_no('TRN'),'COUNT_ADJUST',v_line.item_id,v_count.warehouse_id,v_line.location_id,v_line.lot_id,case when v_line.variance_qty>0 then v_line.variance_qty else 0 end,case when v_line.variance_qty<0 then abs(v_line.variance_qty) else 0 end,v_after,v_line.unit_cost,'stock_counts',p_stock_count_id,'Stock count variance',auth.uid());
  end loop;
  update public.stock_counts set status='approved', approved_by=auth.uid(), approved_at=now() where id=p_stock_count_id;
  return jsonb_build_object('stock_count_id', p_stock_count_id, 'adjustment_id', v_adjustment_id);
end;
$$;

create or replace function public.get_dashboard_summary(p_warehouse_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_result jsonb;
begin
  perform public.assert_active_user();
  select jsonb_build_object(
    'total_skus', (select count(*) from public.items),
    'active_skus', (select count(*) from public.items where is_active),
    'total_inventory_value', coalesce((select sum(total_value) from public.current_stock_view where (p_warehouse_id is null or warehouse_id=p_warehouse_id) and (public.is_admin() or public.user_has_warehouse(warehouse_id,'read'))),0),
    'low_stock_items', (select count(distinct item_id) from public.current_stock_view where (p_warehouse_id is null or warehouse_id=p_warehouse_id) and (public.is_admin() or public.user_has_warehouse(warehouse_id,'read')) and stock_status='low_stock'),
    'out_of_stock_items', (select count(distinct item_id) from public.current_stock_view where (p_warehouse_id is null or warehouse_id=p_warehouse_id) and (public.is_admin() or public.user_has_warehouse(warehouse_id,'read')) and stock_status='out_of_stock'),
    'near_expiry_lots', (select count(*) from public.current_stock_view where (p_warehouse_id is null or warehouse_id=p_warehouse_id) and (public.is_admin() or public.user_has_warehouse(warehouse_id,'read')) and expiry_status='near_expiry'),
    'expired_lots', (select count(*) from public.current_stock_view where (p_warehouse_id is null or warehouse_id=p_warehouse_id) and (public.is_admin() or public.user_has_warehouse(warehouse_id,'read')) and expiry_status='expired'),
    'movements_this_month', (select count(*) from public.stock_transactions where (p_warehouse_id is null or warehouse_id=p_warehouse_id) and (public.is_admin() or public.user_has_warehouse(warehouse_id,'read')) and performed_at >= date_trunc('month', now())),
    'issue_value_this_month', coalesce((select sum(total_cost) from public.stock_transactions where transaction_type='ISSUE' and (p_warehouse_id is null or warehouse_id=p_warehouse_id) and (public.is_admin() or public.user_has_warehouse(warehouse_id,'read')) and performed_at >= date_trunc('month', now())),0),
    'receive_value_this_month', coalesce((select sum(total_cost) from public.stock_transactions where transaction_type='RECEIVE' and (p_warehouse_id is null or warehouse_id=p_warehouse_id) and (public.is_admin() or public.user_has_warehouse(warehouse_id,'read')) and performed_at >= date_trunc('month', now())),0),
    'recent_transactions', coalesce((select jsonb_agg(to_jsonb(x)) from (select transaction_no, transaction_type, item_name, qty_in, qty_out, performed_at from public.stock_movement_view where (p_warehouse_id is null or warehouse_id=p_warehouse_id) and (public.is_admin() or public.user_has_warehouse(warehouse_id,'read')) order by performed_at desc limit 10) x),'[]'::jsonb),
    'top_issued_items', coalesce((select jsonb_agg(to_jsonb(x)) from (select i.item_code, i.item_name, sum(st.qty_out) qty_out from public.stock_transactions st join public.items i on i.id=st.item_id where st.transaction_type='ISSUE' and (p_warehouse_id is null or st.warehouse_id=p_warehouse_id) and (public.is_admin() or public.user_has_warehouse(st.warehouse_id,'read')) group by i.item_code,i.item_name order by qty_out desc limit 10) x),'[]'::jsonb),
    'inventory_value_by_category', coalesce((select jsonb_agg(to_jsonb(x)) from (select coalesce(category_name,'Uncategorized') category_name, sum(total_value) total_value from public.current_stock_view where (p_warehouse_id is null or warehouse_id=p_warehouse_id) and (public.is_admin() or public.user_has_warehouse(warehouse_id,'read')) group by category_name order by total_value desc limit 10) x),'[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;

create or replace function public.get_stock_card(p_item_id uuid, p_warehouse_id uuid default null, p_date_from date default null, p_date_to date default null)
returns table(transaction_no text, transaction_type text, warehouse_name text, lot_no text, qty_in numeric, qty_out numeric, balance_after numeric, unit_cost numeric, reason text, remarks text, performed_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select st.transaction_no, st.transaction_type, w.warehouse_name, sl.lot_no, st.qty_in, st.qty_out, st.balance_after, st.unit_cost, st.reason, st.remarks, st.performed_at
  from public.stock_transactions st
  join public.warehouses w on w.id=st.warehouse_id
  left join public.stock_lots sl on sl.id=st.lot_id
  where st.item_id=p_item_id
    and (p_warehouse_id is null or st.warehouse_id=p_warehouse_id)
    and (public.is_admin() or public.user_has_warehouse(st.warehouse_id,'read'))
    and (p_date_from is null or st.performed_at::date >= p_date_from)
    and (p_date_to is null or st.performed_at::date <= p_date_to)
  order by st.performed_at, st.id;
$$;

create or replace function public.calculate_reorder_recommendation(p_warehouse_id uuid default null)
returns table(item_id uuid, item_code text, item_name text, warehouse_id uuid, warehouse_name text, qty_available numeric, reorder_point numeric, max_stock numeric, average_monthly_usage numeric, days_on_hand numeric, suggested_order_qty numeric, risk_level text)
language sql
stable
security definer
set search_path = public
as $$
  with stock as (
    select csv.item_id, csv.item_code, csv.item_name, csv.warehouse_id, csv.warehouse_name, sum(csv.qty_available) qty_available
    from public.current_stock_view csv
    where (p_warehouse_id is null or csv.warehouse_id=p_warehouse_id) and (public.is_admin() or public.user_has_warehouse(csv.warehouse_id,'read'))
    group by csv.item_id,csv.item_code,csv.item_name,csv.warehouse_id,csv.warehouse_name
  )
  select s.item_id, s.item_code, s.item_name, s.warehouse_id, s.warehouse_name, s.qty_available, i.reorder_point, i.max_stock, i.average_monthly_usage,
         case when i.average_monthly_usage > 0 then round(s.qty_available / (i.average_monthly_usage/30), 1) else 999 end as days_on_hand,
         greatest(i.max_stock - s.qty_available, 0) as suggested_order_qty,
         case when s.qty_available <= 0 then 'critical'
              when s.qty_available <= i.reorder_point then 'high'
              when i.average_monthly_usage > 0 and s.qty_available / (i.average_monthly_usage/30) < 14 then 'medium'
              else 'low' end as risk_level
  from stock s join public.items i on i.id=s.item_id
  where s.qty_available <= greatest(i.reorder_point, i.min_stock) or (i.average_monthly_usage > 0 and s.qty_available / (i.average_monthly_usage/30) < 30)
  order by risk_level, s.item_name;
$$;

grant execute on function public.search_items(text, integer) to authenticated;
grant execute on function public.receive_stock(uuid, uuid, text, date, text, jsonb) to authenticated;
grant execute on function public.issue_stock(uuid, uuid, text, date, text, jsonb) to authenticated;
grant execute on function public.adjust_stock(uuid, text, text, jsonb) to authenticated;
grant execute on function public.transfer_stock(uuid, uuid, text, jsonb) to authenticated;
grant execute on function public.create_stock_count_session(uuid, uuid) to authenticated;
grant execute on function public.approve_stock_count(uuid) to authenticated;
grant execute on function public.get_dashboard_summary(uuid) to authenticated;
grant execute on function public.get_stock_card(uuid, uuid, date, date) to authenticated;
grant execute on function public.calculate_reorder_recommendation(uuid) to authenticated;


-- =========================================================
-- rls_policies.sql
-- =========================================================
-- 05 rls_policies.sql
-- Security must be enforced in database; hiding buttons in frontend is not enough.

alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.departments enable row level security;
alter table public.warehouses enable row level security;
alter table public.profiles enable row level security;
alter table public.user_warehouse_access enable row level security;
alter table public.locations enable row level security;
alter table public.categories enable row level security;
alter table public.units enable row level security;
alter table public.suppliers enable row level security;
alter table public.items enable row level security;
alter table public.item_suppliers enable row level security;
alter table public.stock_lots enable row level security;
alter table public.stock_balances enable row level security;
alter table public.stock_transactions enable row level security;
alter table public.receives enable row level security;
alter table public.receive_items enable row level security;
alter table public.issues enable row level security;
alter table public.issue_items enable row level security;
alter table public.adjustments enable row level security;
alter table public.adjustment_items enable row level security;
alter table public.transfers enable row level security;
alter table public.transfer_items enable row level security;
alter table public.stock_counts enable row level security;
alter table public.stock_count_items enable row level security;
alter table public.audit_logs enable row level security;
alter table public.app_settings enable row level security;
alter table public.notifications enable row level security;

-- Drop helper policies safely
do $$
declare r record;
begin
  for r in select schemaname, tablename, policyname from pg_policies where schemaname='public' loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- Profile
create policy profiles_select_self_or_admin on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin() or public.current_role_code() = 'auditor');
create policy profiles_update_self_limited on public.profiles for update to authenticated using (id = auth.uid() or public.is_admin()) with check (id = auth.uid() or public.is_admin());
create policy profiles_admin_insert on public.profiles for insert to authenticated with check (public.is_admin() or id = auth.uid());

-- Reference data read
create policy roles_read on public.roles for select to authenticated using (true);
create policy permissions_read on public.permissions for select to authenticated using (public.is_admin() or public.current_role_code()='auditor');
create policy role_permissions_read on public.role_permissions for select to authenticated using (public.is_admin() or public.current_role_code()='auditor');
create policy departments_read on public.departments for select to authenticated using (is_active or public.is_admin());
create policy warehouses_read on public.warehouses for select to authenticated using (public.is_admin() or public.current_role_code() in ('auditor','viewer') or public.user_has_warehouse(id, 'read'));
create policy locations_read on public.locations for select to authenticated using (public.is_admin() or public.user_has_warehouse(warehouse_id, 'read'));
create policy categories_read on public.categories for select to authenticated using (is_active or public.is_admin());
create policy units_read on public.units for select to authenticated using (true);
create policy suppliers_read on public.suppliers for select to authenticated using (is_active or public.is_admin());

-- Admin/reference write
create policy reference_admin_write_roles on public.roles for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy reference_admin_write_permissions on public.permissions for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy reference_admin_write_role_permissions on public.role_permissions for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy reference_admin_write_departments on public.departments for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy reference_admin_write_warehouses on public.warehouses for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy reference_admin_write_locations on public.locations for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy reference_admin_write_categories on public.categories for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy reference_admin_write_units on public.units for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy reference_admin_write_suppliers on public.suppliers for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Items: all authenticated can read; manager can write.
create policy items_read on public.items for select to authenticated using (is_active or public.is_admin() or public.current_role_code()='auditor');
create policy items_write on public.items for all to authenticated using (public.current_role_code() in ('super_admin','inventory_manager')) with check (public.current_role_code() in ('super_admin','inventory_manager'));
create policy item_suppliers_read on public.item_suppliers for select to authenticated using (true);
create policy item_suppliers_write on public.item_suppliers for all to authenticated using (public.current_role_code() in ('super_admin','inventory_manager')) with check (public.current_role_code() in ('super_admin','inventory_manager'));

-- Warehouse-scoped stock data
create policy stock_lots_read on public.stock_lots for select to authenticated using (public.is_admin() or public.current_role_code() in ('auditor','viewer') or public.user_has_warehouse(warehouse_id, 'read'));
create policy stock_balances_read on public.stock_balances for select to authenticated using (public.is_admin() or public.current_role_code() in ('auditor','viewer') or public.user_has_warehouse(warehouse_id, 'read'));
create policy stock_transactions_read on public.stock_transactions for select to authenticated using (public.is_admin() or public.current_role_code() in ('auditor','viewer') or public.user_has_warehouse(warehouse_id, 'read'));

-- Block stock balance direct write through RLS; RPC is security definer and trigger also protects it.
create policy stock_balances_no_direct_insert on public.stock_balances for insert to authenticated with check (false);
create policy stock_balances_no_direct_update on public.stock_balances for update to authenticated using (false) with check (false);
create policy stock_balances_no_direct_delete on public.stock_balances for delete to authenticated using (false);

-- Document reads
create policy receives_read on public.receives for select to authenticated using (public.is_admin() or public.current_role_code() in ('auditor','viewer') or public.user_has_warehouse(warehouse_id,'read'));
create policy receive_items_read on public.receive_items for select to authenticated using (exists (select 1 from public.receives r where r.id = receive_id and (public.is_admin() or public.current_role_code() in ('auditor','viewer') or public.user_has_warehouse(r.warehouse_id,'read'))));
create policy issues_read on public.issues for select to authenticated using (public.is_admin() or public.current_role_code() in ('auditor','viewer') or public.user_has_warehouse(warehouse_id,'read'));
create policy issue_items_read on public.issue_items for select to authenticated using (exists (select 1 from public.issues i where i.id = issue_id and (public.is_admin() or public.current_role_code() in ('auditor','viewer') or public.user_has_warehouse(i.warehouse_id,'read'))));
create policy adjustments_read on public.adjustments for select to authenticated using (public.is_admin() or public.current_role_code() in ('auditor','viewer') or public.user_has_warehouse(warehouse_id,'read'));
create policy adjustment_items_read on public.adjustment_items for select to authenticated using (exists (select 1 from public.adjustments a where a.id = adjustment_id and (public.is_admin() or public.current_role_code() in ('auditor','viewer') or public.user_has_warehouse(a.warehouse_id,'read'))));
create policy transfers_read on public.transfers for select to authenticated using (public.is_admin() or public.current_role_code() in ('auditor','viewer') or public.user_has_warehouse(from_warehouse_id,'read') or public.user_has_warehouse(to_warehouse_id,'read'));
create policy transfer_items_read on public.transfer_items for select to authenticated using (exists (select 1 from public.transfers t where t.id = transfer_id and (public.is_admin() or public.current_role_code() in ('auditor','viewer') or public.user_has_warehouse(t.from_warehouse_id,'read') or public.user_has_warehouse(t.to_warehouse_id,'read'))));
create policy stock_counts_read on public.stock_counts for select to authenticated using (public.is_admin() or public.current_role_code() in ('auditor','viewer') or public.user_has_warehouse(warehouse_id,'read'));
create policy stock_count_items_read on public.stock_count_items for select to authenticated using (exists (select 1 from public.stock_counts sc where sc.id=stock_count_id and (public.is_admin() or public.current_role_code() in ('auditor','viewer') or public.user_has_warehouse(sc.warehouse_id,'read'))));

-- Direct inserts/updates for transaction documents are blocked. Use RPC only.
create policy documents_no_direct_write_receives on public.receives for all to authenticated using (false) with check (false);
create policy documents_no_direct_write_receive_items on public.receive_items for all to authenticated using (false) with check (false);
create policy documents_no_direct_write_issues on public.issues for all to authenticated using (false) with check (false);
create policy documents_no_direct_write_issue_items on public.issue_items for all to authenticated using (false) with check (false);
create policy documents_no_direct_write_adjustments on public.adjustments for all to authenticated using (false) with check (false);
create policy documents_no_direct_write_adjustment_items on public.adjustment_items for all to authenticated using (false) with check (false);
create policy documents_no_direct_write_transfers on public.transfers for all to authenticated using (false) with check (false);
create policy documents_no_direct_write_transfer_items on public.transfer_items for all to authenticated using (false) with check (false);
create policy stock_transactions_no_direct_write on public.stock_transactions for all to authenticated using (false) with check (false);

-- Stock count direct update only for entering counted_qty by authorized users; approval through RPC.
create policy stock_count_items_update_counted_qty on public.stock_count_items for update to authenticated using (exists (select 1 from public.stock_counts sc where sc.id=stock_count_id and sc.status in ('open','counting') and public.user_has_warehouse(sc.warehouse_id,'adjust'))) with check (exists (select 1 from public.stock_counts sc where sc.id=stock_count_id and sc.status in ('open','counting') and public.user_has_warehouse(sc.warehouse_id,'adjust')));

-- Warehouse access table
create policy uwa_read on public.user_warehouse_access for select to authenticated using (public.is_admin() or user_id = auth.uid());
create policy uwa_admin_write on public.user_warehouse_access for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Audit logs read only
create policy audit_read_admin_auditor on public.audit_logs for select to authenticated using (public.is_admin() or public.current_role_code()='auditor');
create policy audit_no_write on public.audit_logs for all to authenticated using (false) with check (false);

-- Settings and notifications
create policy app_settings_read on public.app_settings for select to authenticated using (public.is_admin());
create policy app_settings_write on public.app_settings for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy notifications_read on public.notifications for select to authenticated using (target_user = auth.uid() or target_user is null or public.is_admin());
create policy notifications_update_own on public.notifications for update to authenticated using (target_user = auth.uid()) with check (target_user = auth.uid());


-- =========================================================
-- storage_policies.sql
-- =========================================================
-- 06 storage_policies.sql
-- Create bucket for item images.
insert into storage.buckets (id, name, public)
values ('item-images', 'item-images', true)
on conflict (id) do nothing;

drop policy if exists "item images public read" on storage.objects;
create policy "item images public read" on storage.objects
for select to authenticated, anon
using (bucket_id = 'item-images');

drop policy if exists "item images manager upload" on storage.objects;
create policy "item images manager upload" on storage.objects
for insert to authenticated
with check (bucket_id = 'item-images' and public.current_role_code() in ('super_admin','inventory_manager'));

drop policy if exists "item images manager update" on storage.objects;
create policy "item images manager update" on storage.objects
for update to authenticated
using (bucket_id = 'item-images' and public.current_role_code() in ('super_admin','inventory_manager'))
with check (bucket_id = 'item-images' and public.current_role_code() in ('super_admin','inventory_manager'));


-- =========================================================
-- seed.sql
-- =========================================================
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
