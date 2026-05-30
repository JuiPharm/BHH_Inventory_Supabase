-- supabase/user_admin.sql

create or replace function public.admin_create_user(
  p_email text,
  p_password text,
  p_full_name text,
  p_role_code text
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Unauthorized: Only admin can create users';
  end if;

  select id into v_role_id from public.roles where role_code = p_role_code;
  if not found then raise exception 'Invalid role code'; end if;

  v_user_id := gen_random_uuid();

  -- Insert into auth.users (Supabase internal)
  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password, 
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data, 
    created_at, updated_at
  ) values (
    v_user_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', p_email, crypt(p_password, gen_salt('bf')), 
    now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, 
    now(), now()
  );

  insert into public.profiles (id, email, full_name, role_id, is_active)
  values (v_user_id, p_email, p_full_name, v_role_id, true);

  return v_user_id;
end;
$$;

create or replace function public.admin_update_user(
  p_user_id uuid,
  p_full_name text,
  p_role_code text,
  p_is_active boolean
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Unauthorized: Only admin can update users';
  end if;

  select id into v_role_id from public.roles where role_code = p_role_code;
  if not found then raise exception 'Invalid role code'; end if;

  update public.profiles
  set full_name = p_full_name,
      role_id = v_role_id,
      is_active = p_is_active,
      updated_at = now()
  where id = p_user_id;
end;
$$;

grant execute on function public.admin_create_user(text, text, text, text) to authenticated;
grant execute on function public.admin_update_user(uuid, text, text, boolean) to authenticated;
