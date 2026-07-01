-- P0-BE-05: Private document storage.
--
-- Document bytes live in one private bucket. The durable metadata row owns the
-- object path, so Storage RLS can validate account/load/document ownership
-- before accepting uploads or replacements.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'load-documents',
  'load-documents',
  false,
  52428800,
  array[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif'
  ]::text[]
)
on conflict (id) do update
set
  name = excluded.name,
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

comment on column public.documents.object_key is
  'Canonical private Storage object path: user_id/load_id/document_id in the load-documents bucket.';

alter table public.documents
  add constraint documents_object_key_requires_load
    check (object_key is null or load_id is not null),
  add constraint documents_object_key_matches_account_load_document
    check (
      object_key is null
      or object_key = user_id::text || '/' || load_id::text || '/' || id::text
    ),
  add constraint documents_synced_requires_remote_metadata
    check (
      sync_state <> 'synced'
      or (
        load_id is not null
        and object_key is not null
        and sha256_hex is not null
        and byte_count > 0
        and uploaded_at is not null
      )
    );

create or replace function public.is_owned_document_storage_object(object_name text)
returns boolean
language sql
stable
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.documents d
    where d.user_id = (select auth.uid())
      and d.load_id is not null
      and d.object_key = object_name
      and d.object_key = d.user_id::text || '/' || d.load_id::text || '/' || d.id::text
      and d.sync_state <> 'local_only'
  );
$$;

comment on function public.is_owned_document_storage_object(text) is
  'Validates a load-documents object path against the authenticated user and documents metadata row.';

revoke all on function public.is_owned_document_storage_object(text) from public;
grant execute on function public.is_owned_document_storage_object(text) to authenticated, service_role;

grant select, insert, update, delete on table storage.objects to authenticated;

create policy "Users can inspect owned document object internals"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'load-documents'
  and storage.allow_any_operation(array[
    'storage.object.upload',
    'storage.object.upload_update',
    'storage.object.delete',
    'storage.object.delete_many',
    'storage.object.move',
    'storage.object.copy'
  ])
  and public.is_owned_document_storage_object(name)
);

create policy "Users can upload owned document objects"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'load-documents'
  and public.is_owned_document_storage_object(name)
);

create policy "Users can replace owned document objects"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'load-documents'
  and public.is_owned_document_storage_object(name)
)
with check (
  bucket_id = 'load-documents'
  and public.is_owned_document_storage_object(name)
);

create policy "Users can delete owned document objects"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'load-documents'
  and public.is_owned_document_storage_object(name)
);
