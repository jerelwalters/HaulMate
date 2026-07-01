-- P0-BE-04: Tenant isolation policies for load-to-cash tables.
--
-- BE-03 created the owned tables, grants, indexes, and enabled RLS. This
-- migration adds the authenticated ownership policies. Mutable tables allow
-- owned select/insert/update/delete; immutable evidence and invoice revision
-- tables allow owned select/insert only.

do $$
declare
  mutable_table text;
  append_only_table text;
begin
  foreach mutable_table in array array[
    'vehicles',
    'customers',
    'loads',
    'stops',
    'charges',
    'expenses',
    'documents',
    'invoices',
    'payments',
    'tracking_shares',
    'eta_updates'
  ]
  loop
    execute format(
      'create policy %I on public.%I for select to authenticated using ((select auth.uid()) = user_id)',
      'Users can read their own ' || replace(mutable_table, '_', ' '),
      mutable_table
    );

    execute format(
      'create policy %I on public.%I for insert to authenticated with check ((select auth.uid()) = user_id)',
      'Users can create their own ' || replace(mutable_table, '_', ' '),
      mutable_table
    );

    execute format(
      'create policy %I on public.%I for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)',
      'Users can update their own ' || replace(mutable_table, '_', ' '),
      mutable_table
    );

    execute format(
      'create policy %I on public.%I for delete to authenticated using ((select auth.uid()) = user_id)',
      'Users can delete their own ' || replace(mutable_table, '_', ' '),
      mutable_table
    );
  end loop;

  foreach append_only_table in array array[
    'trip_events',
    'invoice_revisions',
    'invoice_items'
  ]
  loop
    execute format(
      'create policy %I on public.%I for select to authenticated using ((select auth.uid()) = user_id)',
      'Users can read their own ' || replace(append_only_table, '_', ' '),
      append_only_table
    );

    execute format(
      'create policy %I on public.%I for insert to authenticated with check ((select auth.uid()) = user_id)',
      'Users can create their own ' || replace(append_only_table, '_', ' '),
      append_only_table
    );
  end loop;
end $$;
