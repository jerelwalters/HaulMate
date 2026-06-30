create policy "Users can read their own business profile"
on public.business_profiles
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create their own business profile"
on public.business_profiles
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can update their own business profile"
on public.business_profiles
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
