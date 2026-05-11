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
