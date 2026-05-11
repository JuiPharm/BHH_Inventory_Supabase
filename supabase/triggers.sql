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
