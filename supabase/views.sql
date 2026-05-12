-- 03 views.sql
-- Safe reset for views whose column names changed.
-- PostgreSQL cannot CREATE OR REPLACE a view when an existing column name changes
-- (for example id -> balance_id), so we drop dependent views first and recreate them.
drop view if exists public.stock_movement_view cascade;
drop view if exists public.inventory_valuation_view cascade;
drop view if exists public.near_expiry_view cascade;
drop view if exists public.low_stock_view cascade;
drop view if exists public.current_stock_view cascade;

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
