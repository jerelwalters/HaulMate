BEGIN;
SET LOCAL search_path = public, extensions;

SELECT plan(16);

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

CREATE OR REPLACE FUNCTION pg_temp.visible_table_failures(expected_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  table_name text;
  visible_count integer;
  owned_count integer;
  failures integer := 0;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'vehicles',
    'customers',
    'loads',
    'stops',
    'trip_events',
    'charges',
    'expenses',
    'documents',
    'invoices',
    'invoice_revisions',
    'invoice_items',
    'payments',
    'tracking_shares',
    'eta_updates'
  ]
  LOOP
    EXECUTE format(
      'SELECT count(*)::integer, count(*) FILTER (WHERE user_id = $1)::integer FROM public.%I',
      table_name
    )
    INTO visible_count, owned_count
    USING expected_user_id;

    IF visible_count <> 1 OR owned_count <> 1 THEN
      failures := failures + 1;
    END IF;
  END LOOP;

  RETURN failures;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.update_other_user_mutable_rows(other_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  table_name text;
  affected_rows integer;
  total_rows integer := 0;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
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
  LOOP
    EXECUTE format(
      'UPDATE public.%I SET updated_at = updated_at WHERE user_id = $1',
      table_name
    )
    USING other_user_id;
    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    total_rows := total_rows + affected_rows;
  END LOOP;

  RETURN total_rows;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.delete_other_user_mutable_rows(other_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  table_name text;
  affected_rows integer;
  total_rows integer := 0;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
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
  LOOP
    EXECUTE format(
      'DELETE FROM public.%I WHERE user_id = $1',
      table_name
    )
    USING other_user_id;
    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    total_rows := total_rows + affected_rows;
  END LOOP;

  RETURN total_rows;
END;
$$;

WITH expected_policies (table_name, command) AS (
  VALUES
    ('vehicles', 'SELECT'),
    ('vehicles', 'INSERT'),
    ('vehicles', 'UPDATE'),
    ('vehicles', 'DELETE'),
    ('customers', 'SELECT'),
    ('customers', 'INSERT'),
    ('customers', 'UPDATE'),
    ('customers', 'DELETE'),
    ('loads', 'SELECT'),
    ('loads', 'INSERT'),
    ('loads', 'UPDATE'),
    ('loads', 'DELETE'),
    ('stops', 'SELECT'),
    ('stops', 'INSERT'),
    ('stops', 'UPDATE'),
    ('stops', 'DELETE'),
    ('trip_events', 'SELECT'),
    ('trip_events', 'INSERT'),
    ('charges', 'SELECT'),
    ('charges', 'INSERT'),
    ('charges', 'UPDATE'),
    ('charges', 'DELETE'),
    ('expenses', 'SELECT'),
    ('expenses', 'INSERT'),
    ('expenses', 'UPDATE'),
    ('expenses', 'DELETE'),
    ('documents', 'SELECT'),
    ('documents', 'INSERT'),
    ('documents', 'UPDATE'),
    ('documents', 'DELETE'),
    ('invoices', 'SELECT'),
    ('invoices', 'INSERT'),
    ('invoices', 'UPDATE'),
    ('invoices', 'DELETE'),
    ('invoice_revisions', 'SELECT'),
    ('invoice_revisions', 'INSERT'),
    ('invoice_items', 'SELECT'),
    ('invoice_items', 'INSERT'),
    ('payments', 'SELECT'),
    ('payments', 'INSERT'),
    ('payments', 'UPDATE'),
    ('payments', 'DELETE'),
    ('tracking_shares', 'SELECT'),
    ('tracking_shares', 'INSERT'),
    ('tracking_shares', 'UPDATE'),
    ('tracking_shares', 'DELETE'),
    ('eta_updates', 'SELECT'),
    ('eta_updates', 'INSERT'),
    ('eta_updates', 'UPDATE'),
    ('eta_updates', 'DELETE')
)
SELECT is(
  (
    SELECT count(*)::integer
    FROM expected_policies e
    WHERE NOT EXISTS (
      SELECT 1
      FROM pg_policies p
      WHERE p.schemaname = 'public'
        AND p.tablename = e.table_name
        AND p.cmd = e.command
        AND p.roles = ARRAY['authenticated']::name[]
    )
  ),
  0,
  'every load-to-cash table has the expected authenticated ownership policies'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
        'vehicles',
        'customers',
        'loads',
        'stops',
        'trip_events',
        'charges',
        'expenses',
        'documents',
        'invoices',
        'invoice_revisions',
        'invoice_items',
        'payments',
        'tracking_shares',
        'eta_updates'
      )
  ),
  50,
  'load-to-cash tables have no extra RLS policies'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
        'vehicles',
        'customers',
        'loads',
        'stops',
        'trip_events',
        'charges',
        'expenses',
        'documents',
        'invoices',
        'invoice_revisions',
        'invoice_items',
        'payments',
        'tracking_shares',
        'eta_updates'
      )
      AND roles <> ARRAY['authenticated']::name[]
  ),
  0,
  'load-to-cash RLS policies target authenticated users only'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('trip_events', 'invoice_revisions', 'invoice_items')
      AND cmd IN ('UPDATE', 'DELETE')
  ),
  0,
  'immutable load-to-cash tables do not expose update or delete policies'
);

INSERT INTO auth.users (id, email, aud, role, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-000000000371', 'be04-owner-a@example.com', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-0000-0000-000000000372', 'be04-owner-b@example.com', 'authenticated', 'authenticated', now(), now());

INSERT INTO public.business_profiles (
  user_id,
  legal_name,
  mailing_address,
  phone,
  invoice_email
)
VALUES
  (
    '00000000-0000-0000-0000-000000000371',
    'Alpha Tenant LLC',
    '100 Alpha Road, Detroit, MI 48201',
    '313-555-0371',
    'billing-alpha-tenant@example.com'
  ),
  (
    '00000000-0000-0000-0000-000000000372',
    'Beta Tenant LLC',
    '200 Beta Road, Detroit, MI 48201',
    '313-555-0372',
    'billing-beta-tenant@example.com'
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
    '00000000-0000-0000-0000-000000000471',
    '00000000-0000-0000-0000-000000000371',
    'Alpha tractor',
    6.70,
    3.64,
    0.35,
    8400.00,
    11350.00
  ),
  (
    '00000000-0000-0000-0000-000000000472',
    '00000000-0000-0000-0000-000000000372',
    'Beta tractor',
    7.10,
    3.50,
    0.30,
    7200.00,
    10500.00
  );

INSERT INTO public.customers (id, user_id, name, kind)
VALUES
  ('00000000-0000-0000-0000-000000000571', '00000000-0000-0000-0000-000000000371', 'Alpha Broker', 'broker'),
  ('00000000-0000-0000-0000-000000000572', '00000000-0000-0000-0000-000000000372', 'Beta Broker', 'broker');

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
    '00000000-0000-0000-0000-000000000671',
    '00000000-0000-0000-0000-000000000371',
    '00000000-0000-0000-0000-000000000471',
    '00000000-0000-0000-0000-000000000571',
    'A-RLS',
    'accepted',
    1000.00,
    100.00
  ),
  (
    '00000000-0000-0000-0000-000000000672',
    '00000000-0000-0000-0000-000000000372',
    '00000000-0000-0000-0000-000000000472',
    '00000000-0000-0000-0000-000000000572',
    'B-RLS',
    'accepted',
    1000.00,
    100.00
  );

INSERT INTO public.stops (
  id,
  user_id,
  load_id,
  kind,
  sequence,
  facility_name
)
VALUES
  ('00000000-0000-0000-0000-000000000771', '00000000-0000-0000-0000-000000000371', '00000000-0000-0000-0000-000000000671', 'pickup', 1, 'Alpha Pickup'),
  ('00000000-0000-0000-0000-000000000772', '00000000-0000-0000-0000-000000000372', '00000000-0000-0000-0000-000000000672', 'pickup', 1, 'Beta Pickup');

INSERT INTO public.trip_events (
  id,
  user_id,
  load_id,
  stop_id,
  kind,
  status,
  occurred_at,
  timezone_identifier,
  location_source
)
VALUES
  (
    '00000000-0000-0000-0000-000000000871',
    '00000000-0000-0000-0000-000000000371',
    '00000000-0000-0000-0000-000000000671',
    '00000000-0000-0000-0000-000000000771',
    'arrived',
    'accepted',
    '2026-07-01 12:00:00+00',
    'America/Detroit',
    'manual'
  ),
  (
    '00000000-0000-0000-0000-000000000872',
    '00000000-0000-0000-0000-000000000372',
    '00000000-0000-0000-0000-000000000672',
    '00000000-0000-0000-0000-000000000772',
    'arrived',
    'accepted',
    '2026-07-01 12:00:00+00',
    'America/Detroit',
    'manual'
  );

INSERT INTO public.charges (id, user_id, load_id, source_trip_event_id, kind, description, amount)
VALUES
  ('00000000-0000-0000-0000-000000001071', '00000000-0000-0000-0000-000000000371', '00000000-0000-0000-0000-000000000671', '00000000-0000-0000-0000-000000000871', 'line_haul', 'Alpha line haul', 1000.00),
  ('00000000-0000-0000-0000-000000001072', '00000000-0000-0000-0000-000000000372', '00000000-0000-0000-0000-000000000672', '00000000-0000-0000-0000-000000000872', 'line_haul', 'Beta line haul', 1000.00);

INSERT INTO public.expenses (id, user_id, load_id, kind, description, amount)
VALUES
  ('00000000-0000-0000-0000-000000001171', '00000000-0000-0000-0000-000000000371', '00000000-0000-0000-0000-000000000671', 'fuel', 'Alpha fuel', 100.00),
  ('00000000-0000-0000-0000-000000001172', '00000000-0000-0000-0000-000000000372', '00000000-0000-0000-0000-000000000672', 'fuel', 'Beta fuel', 100.00);

INSERT INTO public.documents (id, user_id, load_id, kind, file_name, content_type, byte_count)
VALUES
  ('00000000-0000-0000-0000-000000001271', '00000000-0000-0000-0000-000000000371', '00000000-0000-0000-0000-000000000671', 'rate_confirmation', 'alpha-rate.pdf', 'application/pdf', 1024),
  ('00000000-0000-0000-0000-000000001272', '00000000-0000-0000-0000-000000000372', '00000000-0000-0000-0000-000000000672', 'rate_confirmation', 'beta-rate.pdf', 'application/pdf', 1024);

INSERT INTO public.invoices (id, user_id, load_id, invoice_number)
VALUES
  ('00000000-0000-0000-0000-000000001371', '00000000-0000-0000-0000-000000000371', '00000000-0000-0000-0000-000000000671', 'A-RLS-1'),
  ('00000000-0000-0000-0000-000000001372', '00000000-0000-0000-0000-000000000372', '00000000-0000-0000-0000-000000000672', 'B-RLS-1');

INSERT INTO public.invoice_revisions (id, user_id, invoice_id, revision_number, total_amount)
VALUES
  ('00000000-0000-0000-0000-000000001471', '00000000-0000-0000-0000-000000000371', '00000000-0000-0000-0000-000000001371', 1, 1000.00),
  ('00000000-0000-0000-0000-000000001472', '00000000-0000-0000-0000-000000000372', '00000000-0000-0000-0000-000000001372', 1, 1000.00);

INSERT INTO public.invoice_items (
  id,
  user_id,
  invoice_revision_id,
  source_charge_id,
  source_document_id,
  sequence,
  kind,
  description,
  amount
)
VALUES
  (
    '00000000-0000-0000-0000-000000001571',
    '00000000-0000-0000-0000-000000000371',
    '00000000-0000-0000-0000-000000001471',
    '00000000-0000-0000-0000-000000001071',
    '00000000-0000-0000-0000-000000001271',
    1,
    'line_haul',
    'Alpha line haul',
    1000.00
  ),
  (
    '00000000-0000-0000-0000-000000001572',
    '00000000-0000-0000-0000-000000000372',
    '00000000-0000-0000-0000-000000001472',
    '00000000-0000-0000-0000-000000001072',
    '00000000-0000-0000-0000-000000001272',
    1,
    'line_haul',
    'Beta line haul',
    1000.00
  );

INSERT INTO public.payments (id, user_id, invoice_id, amount, received_at)
VALUES
  ('00000000-0000-0000-0000-000000001671', '00000000-0000-0000-0000-000000000371', '00000000-0000-0000-0000-000000001371', 100.00, '2026-07-15 12:00:00+00'),
  ('00000000-0000-0000-0000-000000001672', '00000000-0000-0000-0000-000000000372', '00000000-0000-0000-0000-000000001372', 100.00, '2026-07-15 12:00:00+00');

INSERT INTO public.tracking_shares (id, user_id, load_id, token_hash, expires_at)
VALUES
  ('00000000-0000-0000-0000-000000001771', '00000000-0000-0000-0000-000000000371', '00000000-0000-0000-0000-000000000671', repeat('c', 64), now() + interval '72 hours'),
  ('00000000-0000-0000-0000-000000001772', '00000000-0000-0000-0000-000000000372', '00000000-0000-0000-0000-000000000672', repeat('d', 64), now() + interval '72 hours');

INSERT INTO public.eta_updates (
  id,
  user_id,
  load_id,
  stop_id,
  tracking_share_id,
  estimated_arrival_at,
  generated_at,
  source
)
VALUES
  (
    '00000000-0000-0000-0000-000000001871',
    '00000000-0000-0000-0000-000000000371',
    '00000000-0000-0000-0000-000000000671',
    '00000000-0000-0000-0000-000000000771',
    '00000000-0000-0000-0000-000000001771',
    '2026-07-01 18:00:00+00',
    '2026-07-01 17:30:00+00',
    'manual'
  ),
  (
    '00000000-0000-0000-0000-000000001872',
    '00000000-0000-0000-0000-000000000372',
    '00000000-0000-0000-0000-000000000672',
    '00000000-0000-0000-0000-000000000772',
    '00000000-0000-0000-0000-000000001772',
    '2026-07-01 18:00:00+00',
    '2026-07-01 17:30:00+00',
    'manual'
  );

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000371';

SELECT is(
  auth.uid(),
  '00000000-0000-0000-0000-000000000371'::uuid,
  'test session is impersonating User A'
);

SELECT is(
  pg_temp.visible_table_failures('00000000-0000-0000-0000-000000000371'),
  0,
  'User A sees only their own row in every load-to-cash table'
);

SELECT is(
  pg_temp.update_other_user_mutable_rows('00000000-0000-0000-0000-000000000372'),
  0,
  'User A cannot update User B mutable load-to-cash rows'
);

SELECT is(
  pg_temp.delete_other_user_mutable_rows('00000000-0000-0000-0000-000000000372'),
  0,
  'User A cannot delete User B mutable load-to-cash rows'
);

SELECT ok(
  pg_temp.capture_sqlstate($$
    INSERT INTO public.customers (id, user_id, name, kind)
    VALUES (
      '00000000-0000-0000-0000-000000000579',
      '00000000-0000-0000-0000-000000000371',
      'Alpha Disposable Broker',
      'broker'
    )
  $$) IS NULL,
  'User A can insert their own mutable row'
);

SELECT is(
  pg_temp.capture_row_count($$
    UPDATE public.customers
    SET name = 'Alpha Updated Broker'
    WHERE id = '00000000-0000-0000-0000-000000000579'
  $$),
  1,
  'User A can update their own mutable row'
);

SELECT is(
  pg_temp.capture_row_count($$
    DELETE FROM public.customers
    WHERE id = '00000000-0000-0000-0000-000000000579'
  $$),
  1,
  'User A can delete their own mutable row'
);

SELECT is(
  pg_temp.capture_sqlstate($$
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
    VALUES (
      '00000000-0000-0000-0000-000000000479',
      '00000000-0000-0000-0000-000000000372',
      'Cross-user tractor',
      6.70,
      3.64,
      0.35,
      8400.00,
      11350.00
    )
  $$),
  '42501',
  'User A cannot insert a row owned by User B'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    UPDATE public.vehicles
    SET user_id = '00000000-0000-0000-0000-000000000372'
    WHERE id = '00000000-0000-0000-0000-000000000471'
  $$),
  '42501',
  'User A cannot reassign ownership of their own row'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    UPDATE public.trip_events
    SET note = 'attempted mutable change'
    WHERE id = '00000000-0000-0000-0000-000000000871'
  $$),
  '42501',
  'User A cannot update immutable trip events'
);

SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000372';

SELECT is(
  auth.uid(),
  '00000000-0000-0000-0000-000000000372'::uuid,
  'test session is impersonating User B'
);

SELECT is(
  pg_temp.visible_table_failures('00000000-0000-0000-0000-000000000372'),
  0,
  'User B sees only their own row in every load-to-cash table'
);

RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
