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
