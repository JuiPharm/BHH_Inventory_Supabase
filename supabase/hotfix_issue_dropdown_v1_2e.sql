-- BHH Inventory Hotfix v1.2E
-- Purpose:
-- 1) Clean duplicated Issue destination departments shown in the Issue Stock dropdown.
-- 2) Keep only canonical OPD Pharmacy / IPD Pharmacy / IV Chemo as active issue destinations.
-- 3) Ensure requester is recorded from the authenticated login profile inside issue_stock().
--
-- Safe to run after v1.2C/v1.2D. This does not disable RLS and does not expose service_role.

begin;

-- 1) Canonicalize OPD/IPD/CHEMO departments and move references from duplicate rows.
do $$
declare
  v_code text;
  v_name text;
  v_canonical_id uuid;
  v_codes text[] := array['OPD','IPD','CHEMO'];
  v_names text[] := array['OPD Pharmacy','IPD Pharmacy','IV Chemo'];
  i integer;
begin
  for i in 1..array_length(v_codes, 1) loop
    v_code := v_codes[i];
    v_name := v_names[i];

    select id
      into v_canonical_id
    from public.departments
    where upper(trim(department_code)) = v_code
    order by is_active desc, created_at asc, id asc
    limit 1;

    if v_canonical_id is null then
      insert into public.departments (department_code, department_name, is_active, created_at, updated_at)
      values (v_code, v_name, true, now(), now())
      returning id into v_canonical_id;
    end if;

    update public.departments
    set department_code = v_code,
        department_name = v_name,
        is_active = true,
        updated_at = now()
    where id = v_canonical_id;

    -- Move references from duplicates to canonical row before deactivating duplicates.
    update public.profiles
    set department_id = v_canonical_id,
        updated_at = now()
    where department_id in (
      select id
      from public.departments
      where id <> v_canonical_id
        and (
          upper(trim(department_code)) = v_code
          or lower(trim(department_name)) = lower(v_name)
        )
    );

    update public.warehouses
    set department_id = v_canonical_id,
        updated_at = now()
    where department_id in (
      select id
      from public.departments
      where id <> v_canonical_id
        and (
          upper(trim(department_code)) = v_code
          or lower(trim(department_name)) = lower(v_name)
        )
    );

    update public.issues
    set issue_to_department_id = v_canonical_id
    where issue_to_department_id in (
      select id
      from public.departments
      where id <> v_canonical_id
        and (
          upper(trim(department_code)) = v_code
          or lower(trim(department_name)) = lower(v_name)
        )
    );

    -- Deactivate duplicates and rename their code to avoid future unique-code conflicts.
    update public.departments
    set is_active = false,
        department_code = left(v_code || '_DUP_' || replace(id::text, '-', ''), 60),
        department_name = v_name || ' (inactive duplicate)',
        updated_at = now()
    where id <> v_canonical_id
      and (
        upper(trim(department_code)) = v_code
        or lower(trim(department_name)) = lower(v_name)
      );
  end loop;
end $$;

-- 2) Harden issue_stock requester handling.
-- p_requester_name is kept in the signature for frontend compatibility, but the value recorded
-- is always derived from the authenticated user's profile/auth.uid().
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

  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'Issue items required';
  end if;

  perform set_config('app.stock_rpc', 'on', true);

  if p_issue_to_department_id is null then
    raise exception 'Issue destination department is required';
  end if;

  if not exists (
    select 1
    from public.departments d
    where d.id = p_issue_to_department_id
      and d.is_active = true
      and upper(trim(d.department_code)) in ('OPD','IPD','CHEMO')
  ) then
    raise exception 'Invalid issue destination department. Please select OPD Pharmacy, IPD Pharmacy, or IV Chemo.';
  end if;

  select coalesce(nullif(p.full_name, ''), p.email::text, auth.uid()::text)
    into v_requester_name
  from public.profiles p
  where p.id = auth.uid();

  if v_requester_name is null then
    v_requester_name := auth.uid()::text;
  end if;

  insert into public.issues(
    issue_no,
    issue_to_department_id,
    warehouse_id,
    requester_name,
    issue_date,
    remarks,
    created_by
  )
  values(
    v_issue_no,
    p_issue_to_department_id,
    p_warehouse_id,
    v_requester_name,
    coalesce(p_issue_date, current_date),
    p_remarks,
    auth.uid()
  )
  returning id into v_issue_id;

  for v_line in select * from jsonb_array_elements(p_items) loop
    select *
      into v_item
    from public.items
    where id = (v_line->>'item_id')::uuid
      and is_active = true;

    if not found then
      raise exception 'Item not found or inactive';
    end if;

    v_requested := (v_line->>'qty')::numeric;
    v_remaining := v_requested;
    v_reason := nullif(v_line->>'reason', '');
    v_lot_filter := nullif(v_line->>'lot_id', '')::uuid;

    if v_requested <= 0 then
      raise exception 'Issue quantity must be greater than zero';
    end if;

    if (v_item.is_controlled or v_item.is_high_alert) and coalesce(v_reason, '') = '' then
      raise exception 'Reason is required for controlled/high-alert item %', v_item.item_name;
    end if;

    for v_bal in
      select sb.*, sl.expiry_date, sl.status
      from public.stock_balances sb
      left join public.stock_lots sl on sl.id = sb.lot_id
      where sb.item_id = v_item.id
        and sb.warehouse_id = p_warehouse_id
        and (v_lot_filter is null or sb.lot_id = v_lot_filter)
        and sb.qty_available > 0
        and coalesce(sl.status, 'available') = 'available'
        and (sl.expiry_date is null or sl.expiry_date >= current_date)
      order by sl.expiry_date nulls last, sb.updated_at
    loop
      exit when v_remaining <= 0;

      v_take := least(v_remaining, v_bal.qty_available);

      update public.stock_balances
      set qty_on_hand = qty_on_hand - v_take,
          updated_at = now()
      where id = v_bal.id
      returning qty_on_hand into v_balance_after;

      insert into public.issue_items(issue_id, item_id, lot_id, qty, unit_cost, reason)
      values(v_issue_id, v_item.id, v_bal.lot_id, v_take, v_bal.unit_cost, v_reason);

      insert into public.stock_transactions(
        transaction_no,
        transaction_type,
        item_id,
        warehouse_id,
        location_id,
        lot_id,
        qty_in,
        qty_out,
        balance_after,
        unit_cost,
        reference_type,
        reference_id,
        reason,
        remarks,
        performed_by
      )
      values(
        public.gen_doc_no('TRN'),
        'ISSUE',
        v_item.id,
        p_warehouse_id,
        v_bal.location_id,
        v_bal.lot_id,
        0,
        v_take,
        v_balance_after,
        v_bal.unit_cost,
        'issues',
        v_issue_id,
        v_reason,
        p_remarks,
        auth.uid()
      );

      v_remaining := v_remaining - v_take;
    end loop;

    if v_remaining > 0 then
      raise exception 'Insufficient available stock for %', v_item.item_name;
    end if;
  end loop;

  return jsonb_build_object('issue_id', v_issue_id, 'issue_no', v_issue_no);
end;
$$;

notify pgrst, 'reload schema';

commit;

-- Optional verification after running this hotfix:
-- select department_code, department_name, is_active from public.departments order by department_name, department_code;
-- Expected active Issue destination options in the frontend: OPD Pharmacy, IPD Pharmacy, IV Chemo only.
