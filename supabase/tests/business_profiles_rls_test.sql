BEGIN;
SET LOCAL search_path = public, extensions;

SELECT plan(12);

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

CREATE OR REPLACE FUNCTION pg_temp.capture_row_count(statement text)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  affected_rows integer;
BEGIN
  EXECUTE statement;
  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  RETURN affected_rows;
END;
$$;

INSERT INTO auth.users (id, email, aud, role, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-000000000201', 'rls-owner-a@example.com', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-0000-0000-000000000202', 'rls-owner-b@example.com', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-0000-0000-000000000203', 'rls-owner-c@example.com', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-0000-0000-000000000204', 'rls-owner-d@example.com', 'authenticated', 'authenticated', now(), now());

INSERT INTO public.business_profiles (
  user_id,
  legal_name,
  mailing_address,
  phone,
  invoice_email
)
VALUES
  (
    '00000000-0000-0000-0000-000000000201',
    'Alpha Logistics LLC',
    '100 Alpha Road, Detroit, MI 48201',
    '313-555-0201',
    'billing-alpha@example.com'
  ),
  (
    '00000000-0000-0000-0000-000000000202',
    'Beta Transport LLC',
    '200 Beta Road, Detroit, MI 48201',
    '313-555-0202',
    'billing-beta@example.com'
  );

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'business_profiles'
      AND roles = ARRAY['authenticated']::name[]
  ),
  3,
  'business_profiles has three authenticated RLS policies'
);

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000201';

SELECT is(
  auth.uid(),
  '00000000-0000-0000-0000-000000000201'::uuid,
  'test session is impersonating User A'
);

SELECT is(
  (SELECT count(*)::integer FROM public.business_profiles),
  1,
  'User A sees one visible profile'
);

SELECT is(
  (
    SELECT legal_name
    FROM public.business_profiles
    WHERE user_id = '00000000-0000-0000-0000-000000000201'
  ),
  'Alpha Logistics LLC',
  'User A can read their own profile'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.business_profiles
    WHERE user_id = '00000000-0000-0000-0000-000000000202'
  ),
  0,
  'User A cannot read User B profile'
);

SELECT ok(
  pg_temp.capture_sqlstate($$
    UPDATE public.business_profiles
    SET display_name = 'Alpha Dispatch'
    WHERE user_id = '00000000-0000-0000-0000-000000000201'
  $$) IS NULL,
  'User A can update their own profile'
);

SELECT is(
  pg_temp.capture_row_count($$
    UPDATE public.business_profiles
    SET display_name = 'Should Not Update'
    WHERE user_id = '00000000-0000-0000-0000-000000000202'
  $$),
  0,
  'User A cannot update User B profile'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    UPDATE public.business_profiles
    SET user_id = '00000000-0000-0000-0000-000000000204'
    WHERE user_id = '00000000-0000-0000-0000-000000000201'
  $$),
  '42501',
  'User A cannot reassign profile ownership'
);

SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000203';

SELECT ok(
  pg_temp.capture_sqlstate($$
    INSERT INTO public.business_profiles (
      user_id,
      legal_name,
      mailing_address,
      phone,
      invoice_email
    )
    VALUES (
      '00000000-0000-0000-0000-000000000203',
      'Charlie Freight LLC',
      '300 Charlie Road, Detroit, MI 48201',
      '313-555-0203',
      'billing-charlie@example.com'
    )
  $$) IS NULL,
  'User C can create their own profile'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    INSERT INTO public.business_profiles (
      user_id,
      legal_name,
      mailing_address,
      phone,
      invoice_email
    )
    VALUES (
      '00000000-0000-0000-0000-000000000204',
      'Delta Freight LLC',
      '400 Delta Road, Detroit, MI 48201',
      '313-555-0204',
      'billing-delta@example.com'
    )
  $$),
  '42501',
  'User C cannot create a profile for User D'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.business_profiles
    WHERE user_id = '00000000-0000-0000-0000-000000000201'
  ),
  0,
  'User C cannot read User A profile'
);

SELECT is(
  (
    SELECT legal_name
    FROM public.business_profiles
    WHERE user_id = '00000000-0000-0000-0000-000000000203'
  ),
  'Charlie Freight LLC',
  'User C can read their own inserted profile'
);

RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
