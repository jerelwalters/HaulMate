BEGIN;
SET LOCAL search_path = public, storage, extensions;

SELECT plan(19);

CREATE OR REPLACE FUNCTION pg_temp.capture_sqlstate(statement text)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  EXECUTE statement;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RETURN SQLSTATE;
END;
$$;

SELECT ok(
  EXISTS (
    SELECT 1
    FROM storage.buckets
    WHERE id = 'load-documents'
      AND name = 'load-documents'
      AND public = false
  ),
  'load-documents bucket exists and is private'
);

SELECT is(
  (
    SELECT file_size_limit
    FROM storage.buckets
    WHERE id = 'load-documents'
  ),
  52428800::bigint,
  'load-documents bucket caps files at 50 MiB'
);

SELECT is(
  (
    SELECT allowed_mime_types
    FROM storage.buckets
    WHERE id = 'load-documents'
  ),
  array[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif'
  ]::text[],
  'load-documents bucket accepts P0 document MIME types'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname LIKE 'Users can % document object%'
      AND roles = ARRAY['authenticated']::name[]
  ),
  4,
  'storage.objects has four authenticated document object policies'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname LIKE 'Users can % document object%'
      AND (
        coalesce(qual, '') ILIKE '%storage.object.sign%'
        OR coalesce(with_check, '') ILIKE '%storage.object.sign%'
        OR coalesce(qual, '') ILIKE '%storage.object.list%'
        OR coalesce(with_check, '') ILIKE '%storage.object.list%'
      )
  ),
  0,
  'document object policies do not allow client-side signing or listing'
);

INSERT INTO auth.users (id, email, aud, role, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-000000000381', 'be05-owner-a@example.com', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-0000-0000-000000000382', 'be05-owner-b@example.com', 'authenticated', 'authenticated', now(), now());

INSERT INTO public.business_profiles (
  user_id,
  legal_name,
  mailing_address,
  phone,
  invoice_email
)
VALUES
  (
    '00000000-0000-0000-0000-000000000381',
    'Storage Alpha LLC',
    '100 Storage Road, Detroit, MI 48201',
    '313-555-0381',
    'billing-storage-alpha@example.com'
  ),
  (
    '00000000-0000-0000-0000-000000000382',
    'Storage Beta LLC',
    '200 Storage Road, Detroit, MI 48201',
    '313-555-0382',
    'billing-storage-beta@example.com'
  );

INSERT INTO public.vehicles (
  id,
  user_id,
  equipment_name,
  fuel_economy_mpg,
  fuel_price_per_gallon,
  maintenance_reserve_per_mile,
  monthly_fixed_costs,
  estimated_working_miles
)
VALUES
  (
    '00000000-0000-0000-0000-000000000481',
    '00000000-0000-0000-0000-000000000381',
    'Alpha storage tractor',
    6.70,
    3.64,
    0.35,
    8400.00,
    11350.00
  ),
  (
    '00000000-0000-0000-0000-000000000482',
    '00000000-0000-0000-0000-000000000382',
    'Beta storage tractor',
    7.10,
    3.50,
    0.30,
    7200.00,
    10500.00
  );

INSERT INTO public.customers (id, user_id, name, kind)
VALUES
  ('00000000-0000-0000-0000-000000000581', '00000000-0000-0000-0000-000000000381', 'Alpha Storage Broker', 'broker'),
  ('00000000-0000-0000-0000-000000000582', '00000000-0000-0000-0000-000000000382', 'Beta Storage Broker', 'broker');

INSERT INTO public.loads (
  id,
  user_id,
  vehicle_id,
  customer_id,
  reference_number,
  status,
  line_haul_rate,
  loaded_miles
)
VALUES
  (
    '00000000-0000-0000-0000-000000000681',
    '00000000-0000-0000-0000-000000000381',
    '00000000-0000-0000-0000-000000000481',
    '00000000-0000-0000-0000-000000000581',
    'A-STORAGE',
    'accepted',
    1000.00,
    100.00
  ),
  (
    '00000000-0000-0000-0000-000000000682',
    '00000000-0000-0000-0000-000000000382',
    '00000000-0000-0000-0000-000000000482',
    '00000000-0000-0000-0000-000000000582',
    'B-STORAGE',
    'accepted',
    1000.00,
    100.00
  );

SELECT lives_ok(
  $$
    INSERT INTO public.documents (
      id,
      user_id,
      load_id,
      kind,
      file_name,
      content_type,
      byte_count,
      sha256_hex,
      object_key,
      sync_state,
      uploaded_at
    )
    VALUES (
      '00000000-0000-0000-0000-000000001281',
      '00000000-0000-0000-0000-000000000381',
      '00000000-0000-0000-0000-000000000681',
      'proof_of_delivery',
      'alpha-pod.pdf',
      'application/pdf',
      2048,
      repeat('a', 64),
      '00000000-0000-0000-0000-000000000381/00000000-0000-0000-0000-000000000681/00000000-0000-0000-0000-000000001281',
      'synced',
      '2026-07-01 12:00:00+00'
    )
  $$,
  'synced document metadata accepts the canonical account/load/document object key'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    INSERT INTO public.documents (
      id,
      user_id,
      load_id,
      kind,
      file_name,
      content_type,
      byte_count,
      object_key,
      sync_state
    )
    VALUES (
      '00000000-0000-0000-0000-000000001282',
      '00000000-0000-0000-0000-000000000381',
      '00000000-0000-0000-0000-000000000681',
      'receipt',
      'missing-hash.pdf',
      'application/pdf',
      2048,
      '00000000-0000-0000-0000-000000000381/00000000-0000-0000-0000-000000000681/00000000-0000-0000-0000-000000001282',
      'synced'
    )
  $$),
  '23514',
  'synced document metadata requires hash and uploaded_at'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    INSERT INTO public.documents (
      id,
      user_id,
      load_id,
      kind,
      file_name,
      content_type,
      byte_count,
      sha256_hex,
      object_key,
      sync_state,
      uploaded_at
    )
    VALUES (
      '00000000-0000-0000-0000-000000001283',
      '00000000-0000-0000-0000-000000000381',
      '00000000-0000-0000-0000-000000000681',
      'receipt',
      'wrong-key.pdf',
      'application/pdf',
      2048,
      repeat('b', 64),
      '00000000-0000-0000-0000-000000000381/00000000-0000-0000-0000-000000000681/00000000-0000-0000-0000-00000000ffff',
      'synced',
      '2026-07-01 12:00:00+00'
    )
  $$),
  '23514',
  'document object_key must match its own document id'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    INSERT INTO public.documents (
      id,
      user_id,
      kind,
      file_name,
      content_type,
      byte_count,
      sha256_hex,
      object_key,
      sync_state,
      uploaded_at
    )
    VALUES (
      '00000000-0000-0000-0000-000000001284',
      '00000000-0000-0000-0000-000000000381',
      'receipt',
      'missing-load.pdf',
      'application/pdf',
      2048,
      repeat('c', 64),
      '00000000-0000-0000-0000-000000000381/00000000-0000-0000-0000-000000000681/00000000-0000-0000-0000-000000001284',
      'synced',
      '2026-07-01 12:00:00+00'
    )
  $$),
  '23514',
  'document object_key requires a load'
);

INSERT INTO public.documents (
  id,
  user_id,
  load_id,
  kind,
  file_name,
  content_type,
  byte_count,
  sha256_hex,
  object_key,
  sync_state,
  uploaded_at
)
VALUES
  (
    '00000000-0000-0000-0000-000000001285',
    '00000000-0000-0000-0000-000000000382',
    '00000000-0000-0000-0000-000000000682',
    'proof_of_delivery',
    'beta-pod.pdf',
    'application/pdf',
    2048,
    repeat('d', 64),
    '00000000-0000-0000-0000-000000000382/00000000-0000-0000-0000-000000000682/00000000-0000-0000-0000-000000001285',
    'synced',
    '2026-07-01 12:00:00+00'
  );

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000381';

SELECT ok(
  public.is_owned_document_storage_object(
    '00000000-0000-0000-0000-000000000381/00000000-0000-0000-0000-000000000681/00000000-0000-0000-0000-000000001281'
  ),
  'User A storage object path validates against owned document metadata'
);

SELECT ok(
  NOT public.is_owned_document_storage_object(
    '00000000-0000-0000-0000-000000000382/00000000-0000-0000-0000-000000000682/00000000-0000-0000-0000-000000001285'
  ),
  'User A storage object path does not validate against User B metadata'
);

SELECT ok(
  pg_temp.capture_sqlstate($$
    INSERT INTO storage.objects (
      bucket_id,
      name,
      owner,
      metadata
    )
    VALUES (
      'load-documents',
      '00000000-0000-0000-0000-000000000381/00000000-0000-0000-0000-000000000681/00000000-0000-0000-0000-000000001281',
      '00000000-0000-0000-0000-000000000381',
      '{"mimetype":"application/pdf","size":2048}'::jsonb
    )
  $$) IS NULL,
  'User A can upload an object matching owned document metadata'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    INSERT INTO storage.objects (
      bucket_id,
      name,
      owner,
      metadata
    )
    VALUES (
      'load-documents',
      '00000000-0000-0000-0000-000000000382/00000000-0000-0000-0000-000000000682/00000000-0000-0000-0000-000000001285',
      '00000000-0000-0000-0000-000000000381',
      '{"mimetype":"application/pdf","size":2048}'::jsonb
    )
  $$),
  '42501',
  'User A cannot upload an object for User B document metadata'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    INSERT INTO storage.objects (
      bucket_id,
      name,
      owner,
      metadata
    )
    VALUES (
      'load-documents',
      '00000000-0000-0000-0000-000000000381/00000000-0000-0000-0000-000000000681/00000000-0000-0000-0000-00000000ffff',
      '00000000-0000-0000-0000-000000000381',
      '{"mimetype":"application/pdf","size":2048}'::jsonb
    )
  $$),
  '42501',
  'User A cannot upload an object without matching document metadata'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM storage.objects
    WHERE bucket_id = 'load-documents'
  ),
  0,
  'raw object selects are not enumerable without a Storage operation'
);

SELECT set_config('storage.operation', 'storage.object.list', true);

SELECT is(
  (
    SELECT count(*)::integer
    FROM storage.objects
    WHERE bucket_id = 'load-documents'
  ),
  0,
  'document objects are not enumerable through Storage list operations'
);

SELECT set_config('storage.operation', 'storage.object.sign', true);

SELECT is(
  (
    SELECT count(*)::integer
    FROM storage.objects
    WHERE bucket_id = 'load-documents'
  ),
  0,
  'clients cannot sign document objects directly'
);

SELECT set_config('storage.operation', 'storage.object.upload', true);

SELECT is(
  (
    SELECT count(*)::integer
    FROM storage.objects
    WHERE bucket_id = 'load-documents'
  ),
  1,
  'Storage upload internals can inspect the owned object'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Users can delete owned document objects'
      AND cmd = 'DELETE'
      AND roles = ARRAY['authenticated']::name[]
  ),
  1,
  'authenticated users have a Storage API delete policy for owned document objects'
);

RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
