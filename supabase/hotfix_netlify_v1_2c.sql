-- BHH Inventory Netlify Hotfix v1.2c
-- Fixes:
-- 1) RPC schema mismatch: get_dashboard_summary(p_warehouse_id), calculate_reorder_recommendation(p_warehouse_id)
-- 2) near_expiry_view.days_to_expiry missing
-- 3) Issue destination departments: OPD Pharmacy, IPD Pharmacy, IV Chemo
-- 4) Requester name defaults to current login profile/email
-- 5) FIX: drop existing views before recreating them to avoid column rename error
-- 6) FIX: include required helper functions before they are called

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;


-- Required helper functions.
-- This block is intentionally included in the hotfix because some existing databases
-- may not have run the original functions.sql before this patch.
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
      select 1
      from public.user_warehouse_access uwa
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
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.default_warehouse_id = p_warehouse_id
        and p.is_active = true
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
  if auth.uid() is null then
    raise exception 'Login required';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and is_active = true
  ) then
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

  if public.is_readonly_role() then
    raise exception 'Read-only role cannot perform this action';
  end if;

  if p_warehouse_id is null then
    raise exception 'Warehouse is required';
  end if;

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

grant execute on function public.current_role_code() to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_readonly_role() to authenticated;
grant execute on function public.user_has_warehouse(uuid, text) to authenticated;
grant execute on function public.assert_active_user() to authenticated;
grant execute on function public.assert_warehouse_permission(uuid, text) to authenticated;
grant execute on function public.gen_doc_no(text) to authenticated;

insert into public.departments(department_code, department_name, is_active) values
('PHARM','Pharmacy',true),
('CHEMO','IV Chemo',true),
('OPD','OPD Pharmacy',true),
('IPD','IPD Pharmacy',true)
on conflict(department_code) do update
set department_name = excluded.department_name,
    is_active = true,
    updated_at = now();

-- Recreate stock/expiry views with days_to_expiry column.
-- Safe reset for views whose column names changed.
-- PostgreSQL cannot CREATE OR REPLACE a view when an existing column name changes
-- (for example id -> balance_id), so we drop dependent views first and recreate them.
drop view if exists public.stock_movement_view cascade;
drop view if exists public.inventory_valuation_view cascade;
drop view if exists public.near_expiry_view cascade;
drop view if exists public.low_stock_view cascade;
drop view if exists public.current_stock_view cascade;

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


-- Remove older no-parameter RPC versions if present, then create parameterized versions.
drop function if exists public.get_dashboard_summary();
drop function if exists public.calculate_reorder_recommendation();

-- Recreate issue_stock so requester is derived from current login when not provided and destination department is required.
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
  v_requester_name text;
  v_lot_filter uuid;
  v_bal record;
  v_take numeric;
  v_balance_after numeric;
begin
  perform public.assert_warehouse_permission(p_warehouse_id, 'issue');
  if p_items is null or jsonb_array_length(p_items) = 0 then raise exception 'Issue items required'; end if;
  perform set_config('app.stock_rpc','on', true);

  if p_issue_to_department_id is null then
    raise exception 'Issue destination department is required';
  end if;

  select coalesce(nullif(p_requester_name,''), nullif(p.full_name,''), p.email::text, auth.uid()::text)
  into v_requester_name
  from public.profiles p
  where p.id = auth.uid();

  insert into public.issues(issue_no, issue_to_department_id, warehouse_id, requester_name, issue_date, remarks, created_by)
  values(v_issue_no, p_issue_to_department_id, p_warehouse_id, v_requester_name, coalesce(p_issue_date,current_date), p_remarks, auth.uid())
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



-- Recreate dashboard/reorder RPC functions with p_warehouse_id parameter.
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



grant execute on function public.issue_stock(uuid, uuid, text, date, text, jsonb) to authenticated;
grant execute on function public.get_dashboard_summary(uuid) to authenticated;
grant execute on function public.calculate_reorder_recommendation(uuid) to authenticated;

-- Force Supabase/PostgREST to reload schema cache.
notify pgrst, 'reload schema';
