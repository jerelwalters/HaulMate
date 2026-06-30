BEGIN;
SET LOCAL search_path = public, extensions;

SELECT plan(21);

SELECT has_table('public', 'business_profiles', 'business_profiles table exists');
SELECT col_is_pk('public', 'business_profiles', 'user_id', 'user_id is the primary key');
SELECT col_not_null('public', 'business_profiles', 'legal_name', 'legal_name is required');
SELECT col_has_default('public', 'business_profiles', 'invoice_prefix', 'invoice_prefix has a default');
SELECT col_has_default('public', 'business_profiles', 'payment_terms_days', 'payment_terms_days has a default');
SELECT col_has_default('public', 'business_profiles', 'uses_factoring', 'uses_factoring has a default');
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.business_profiles'::regclass),
  'business_profiles has RLS enabled'
);
SELECT ok(
  NOT has_table_privilege('anon', 'public.business_profiles', 'select'),
  'anon cannot access business_profiles'
);
SELECT ok(
  has_table_privilege('authenticated', 'public.business_profiles', 'select')
  AND has_table_privilege('authenticated', 'public.business_profiles', 'insert')
  AND has_table_privilege('authenticated', 'public.business_profiles', 'update')
  AND NOT has_table_privilege('authenticated', 'public.business_profiles', 'delete'),
  'authenticated has read/write profile grants except delete'
);
SELECT ok(
  has_table_privilege('service_role', 'public.business_profiles', 'select')
  AND has_table_privilege('service_role', 'public.business_profiles', 'insert')
  AND has_table_privilege('service_role', 'public.business_profiles', 'update')
  AND has_table_privilege('service_role', 'public.business_profiles', 'delete'),
  'service_role has full profile grants'
);

INSERT INTO auth.users (id, email, aud, role, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-000000000101', 'profile-owner@example.com', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-0000-0000-000000000102', 'cascade-owner@example.com', 'authenticated', 'authenticated', now(), now());

SELECT lives_ok(
  $$
    INSERT INTO public.business_profiles (
      user_id,
      legal_name,
      mailing_address,
      phone,
      invoice_email
    )
    VALUES (
      '00000000-0000-0000-0000-000000000101',
      'Walters Logistics LLC',
      '123 Pilot Way, Detroit, MI 48201',
      '313-555-0148',
      'billing@example.com'
    )
  $$,
  'valid minimum business profile can be inserted'
);

SELECT is(
  (SELECT invoice_prefix FROM public.business_profiles WHERE user_id = '00000000-0000-0000-0000-000000000101'),
  'HM',
  'invoice_prefix defaults to HM'
);
SELECT is(
  (SELECT payment_terms_days FROM public.business_profiles WHERE user_id = '00000000-0000-0000-0000-000000000101'),
  30,
  'payment_terms_days defaults to 30'
);
SELECT is(
  (SELECT uses_factoring FROM public.business_profiles WHERE user_id = '00000000-0000-0000-0000-000000000101'),
  false,
  'uses_factoring defaults to false'
);

SELECT throws_ok(
  $$
    INSERT INTO public.business_profiles (
      user_id,
      legal_name,
      mailing_address,
      phone,
      invoice_email
    )
    VALUES (
      '00000000-0000-0000-0000-000000000102',
      '   ',
      '123 Pilot Way, Detroit, MI 48201',
      '313-555-0148',
      'billing@example.com'
    )
  $$,
  '23514',
  'new row for relation "business_profiles" violates check constraint "business_profiles_legal_name_required"',
  'blank legal_name is rejected'
);

SELECT throws_ok(
  $$
    INSERT INTO public.business_profiles (
      user_id,
      legal_name,
      mailing_address,
      phone,
      invoice_email
    )
    VALUES (
      '00000000-0000-0000-0000-000000000102',
      'Walters Logistics LLC',
      '123 Pilot Way, Detroit, MI 48201',
      '313-555-0148',
      'billing'
    )
  $$,
  '23514',
  'new row for relation "business_profiles" violates check constraint "business_profiles_invoice_email_format"',
  'invalid invoice_email is rejected'
);

SELECT throws_ok(
  $$
    INSERT INTO public.business_profiles (
      user_id,
      legal_name,
      mailing_address,
      phone,
      invoice_email,
      payment_terms_days
    )
    VALUES (
      '00000000-0000-0000-0000-000000000102',
      'Walters Logistics LLC',
      '123 Pilot Way, Detroit, MI 48201',
      '313-555-0148',
      'billing@example.com',
      0
    )
  $$,
  '23514',
  'new row for relation "business_profiles" violates check constraint "business_profiles_payment_terms_positive"',
  'non-positive payment_terms_days is rejected'
);

SELECT throws_ok(
  $$
    INSERT INTO public.business_profiles (
      user_id,
      legal_name,
      mailing_address,
      phone,
      invoice_email,
      uses_factoring
    )
    VALUES (
      '00000000-0000-0000-0000-000000000102',
      'Walters Logistics LLC',
      '123 Pilot Way, Detroit, MI 48201',
      '313-555-0148',
      'billing@example.com',
      true
    )
  $$,
  '23514',
  'new row for relation "business_profiles" violates check constraint "business_profiles_factoring_company_required"',
  'factoring details are required when factoring is enabled'
);

SELECT throws_ok(
  $$
    INSERT INTO public.business_profiles (
      user_id,
      legal_name,
      mailing_address,
      phone,
      invoice_email
    )
    VALUES (
      '00000000-0000-0000-0000-000000000999',
      'Walters Logistics LLC',
      '123 Pilot Way, Detroit, MI 48201',
      '313-555-0148',
      'billing@example.com'
    )
  $$,
  '23503',
  'insert or update on table "business_profiles" violates foreign key constraint "business_profiles_user_id_fkey"',
  'business profile requires an auth user'
);

UPDATE public.business_profiles
SET updated_at = '2020-01-01 00:00:00+00'
WHERE user_id = '00000000-0000-0000-0000-000000000101';

UPDATE public.business_profiles
SET legal_name = 'Walters Transport LLC'
WHERE user_id = '00000000-0000-0000-0000-000000000101';

SELECT ok(
  (SELECT updated_at > '2020-01-01 00:00:00+00'::timestamp with time zone
   FROM public.business_profiles
   WHERE user_id = '00000000-0000-0000-0000-000000000101'),
  'updated_at refreshes on profile update'
);

INSERT INTO public.business_profiles (
  user_id,
  legal_name,
  mailing_address,
  phone,
  invoice_email
)
VALUES (
  '00000000-0000-0000-0000-000000000102',
  'Cascade Transport LLC',
  '456 Pilot Way, Detroit, MI 48201',
  '313-555-0111',
  'billing-cascade@example.com'
);

DELETE FROM auth.users
WHERE id = '00000000-0000-0000-0000-000000000102';

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM public.business_profiles
    WHERE user_id = '00000000-0000-0000-0000-000000000102'
  ),
  'deleting an auth user cascades to business_profiles'
);

SELECT * FROM finish();
ROLLBACK;
