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
