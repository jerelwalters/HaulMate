BEGIN;
SET LOCAL search_path = public, extensions;

SELECT plan(45);

CREATE TEMP TABLE be03_tables (
  table_name text primary key
) ON COMMIT DROP;

INSERT INTO be03_tables (table_name)
VALUES
  ('vehicles'),
  ('customers'),
  ('loads'),
  ('stops'),
  ('trip_events'),
  ('charges'),
  ('expenses'),
  ('documents'),
  ('invoices'),
  ('invoice_revisions'),
  ('invoice_items'),
  ('payments'),
  ('tracking_shares'),
  ('eta_updates');

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

SELECT has_table('public', 'vehicles', 'vehicles table exists');
SELECT has_table('public', 'customers', 'customers table exists');
SELECT has_table('public', 'loads', 'loads table exists');
SELECT has_table('public', 'stops', 'stops table exists');
SELECT has_table('public', 'trip_events', 'trip_events table exists');
SELECT has_table('public', 'charges', 'charges table exists');
SELECT has_table('public', 'expenses', 'expenses table exists');
SELECT has_table('public', 'documents', 'documents table exists');
SELECT has_table('public', 'invoices', 'invoices table exists');
SELECT has_table('public', 'invoice_revisions', 'invoice_revisions table exists');
SELECT has_table('public', 'invoice_items', 'invoice_items table exists');
SELECT has_table('public', 'payments', 'payments table exists');
SELECT has_table('public', 'tracking_shares', 'tracking_shares table exists');
SELECT has_table('public', 'eta_updates', 'eta_updates table exists');

SELECT is(
  (
    SELECT count(*)::integer
    FROM be03_tables t
    JOIN pg_constraint c
      ON c.conrelid = format('public.%I', t.table_name)::regclass
     AND c.contype = 'p'
    JOIN pg_attribute a
      ON a.attrelid = c.conrelid
     AND a.attnum = ANY(c.conkey)
     AND a.attname = 'id'
  ),
  14,
  'all load-to-cash tables use id as a client UUID primary key'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM be03_tables t
    WHERE EXISTS (
      SELECT 1
      FROM information_schema.columns c
      WHERE c.table_schema = 'public'
        AND c.table_name = t.table_name
        AND c.column_name = 'user_id'
        AND c.data_type = 'uuid'
        AND c.is_nullable = 'NO'
    )
  ),
  14,
  'all load-to-cash tables have a required user_id owner column'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM be03_tables t
    WHERE EXISTS (
      SELECT 1
      FROM information_schema.columns c
      WHERE c.table_schema = 'public'
        AND c.table_name = t.table_name
        AND c.column_name = 'created_at'
        AND c.data_type = 'timestamp with time zone'
        AND c.is_nullable = 'NO'
    )
    AND EXISTS (
      SELECT 1
      FROM information_schema.columns c
      WHERE c.table_schema = 'public'
        AND c.table_name = t.table_name
        AND c.column_name = 'updated_at'
        AND c.data_type = 'timestamp with time zone'
        AND c.is_nullable = 'NO'
    )
  ),
  14,
  'all load-to-cash tables have required UTC-safe timestamp columns'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM be03_tables t
    JOIN information_schema.columns c
      ON c.table_schema = 'public'
     AND c.table_name = t.table_name
     AND c.column_name = 'id'
     AND c.column_default IS NULL
  ),
  14,
  'load-to-cash ids do not default on the server'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM be03_tables t
    JOIN pg_class rel
      ON rel.oid = format('public.%I', t.table_name)::regclass
     AND rel.relrowsecurity
  ),
  14,
  'RLS is enabled on every load-to-cash table'
);

SELECT ok(
  (
    SELECT bool_and(NOT has_table_privilege('anon', format('public.%I', table_name), 'select'))
    FROM be03_tables
  ),
  'anon has no direct table grants for load-to-cash tables'
);

SELECT ok(
  (
    SELECT bool_and(
      has_table_privilege('authenticated', format('public.%I', table_name), 'select')
      AND has_table_privilege('authenticated', format('public.%I', table_name), 'insert')
      AND has_table_privilege('authenticated', format('public.%I', table_name), 'update')
      AND has_table_privilege('authenticated', format('public.%I', table_name), 'delete')
    )
    FROM be03_tables
    WHERE table_name NOT IN ('trip_events', 'invoice_revisions', 'invoice_items')
  ),
  'authenticated has read/write grants on mutable load-to-cash tables'
);

SELECT ok(
  (
    SELECT bool_and(
      has_table_privilege('authenticated', format('public.%I', table_name), 'select')
      AND has_table_privilege('authenticated', format('public.%I', table_name), 'insert')
      AND NOT has_table_privilege('authenticated', format('public.%I', table_name), 'update')
      AND NOT has_table_privilege('authenticated', format('public.%I', table_name), 'delete')
    )
    FROM be03_tables
    WHERE table_name IN ('trip_events', 'invoice_revisions', 'invoice_items')
  ),
  'authenticated can append but not mutate immutable evidence and invoice revision rows'
);

SELECT ok(
  (
    SELECT bool_and(
      has_table_privilege('service_role', format('public.%I', table_name), 'select')
      AND has_table_privilege('service_role', format('public.%I', table_name), 'insert')
      AND has_table_privilege('service_role', format('public.%I', table_name), 'update')
      AND has_table_privilege('service_role', format('public.%I', table_name), 'delete')
    )
    FROM be03_tables
  ),
  'service_role has full table grants for privileged backend operations'
);

SELECT is(
  (
    SELECT count(DISTINCT t.table_name)::integer
    FROM be03_tables t
    JOIN pg_indexes i
      ON i.schemaname = 'public'
     AND i.tablename = t.table_name
     AND i.indexdef LIKE '%(user_id%'
  ),
  14,
  'every load-to-cash table has a user_id index for ownership filters and future RLS'
);

INSERT INTO auth.users (id, email, aud, role, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-000000000301', 'be03-owner-a@example.com', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-0000-0000-000000000302', 'be03-owner-b@example.com', 'authenticated', 'authenticated', now(), now());

INSERT INTO public.business_profiles (
  user_id,
  legal_name,
  mailing_address,
  phone,
  invoice_email
)
VALUES
  (
    '00000000-0000-0000-0000-000000000301',
    'Alpha Hauling LLC',
    '100 Alpha Road, Detroit, MI 48201',
    '313-555-0301',
    'billing-alpha@example.com'
  ),
  (
    '00000000-0000-0000-0000-000000000302',
    'Beta Hauling LLC',
    '200 Beta Road, Detroit, MI 48201',
    '313-555-0302',
    'billing-beta@example.com'
  );

SELECT lives_ok(
  $$
    INSERT INTO public.vehicles (
      id,
      user_id,
      equipment_name,
      fuel_economy_mpg,
      fuel_price_per_gallon,
      maintenance_reserve_per_mile,
      monthly_fixed_costs,
      estimated_working_miles,
      dispatch_fee_percent,
      factoring_fee_percent,
      profit_target_percent,
      is_default
    )
    VALUES
      (
        '00000000-0000-0000-0000-000000000401',
        '00000000-0000-0000-0000-000000000301',
        'Tractor-trailer',
        6.70,
        3.64,
        0.35,
        8400.00,
        11350.00,
        5.00,
        3.00,
        25.00,
        true
      ),
      (
        '00000000-0000-0000-0000-000000000402',
        '00000000-0000-0000-0000-000000000302',
        'Box truck',
        9.20,
        3.50,
        0.20,
        4200.00,
        7500.00,
        0.00,
        0.00,
        20.00,
        true
      );

    INSERT INTO public.customers (
      id,
      user_id,
      name,
      kind,
      email
    )
    VALUES
      (
        '00000000-0000-0000-0000-000000000501',
        '00000000-0000-0000-0000-000000000301',
        'Acme Logistics',
        'broker',
        'dispatch-acme@example.com'
      ),
      (
        '00000000-0000-0000-0000-000000000502',
        '00000000-0000-0000-0000-000000000302',
        'Beta Broker',
        'broker',
        'dispatch-beta@example.com'
      );

    INSERT INTO public.loads (
      id,
      user_id,
      vehicle_id,
      customer_id,
      reference_number,
      status,
      line_haul_rate,
      fuel_surcharge,
      accessorial_revenue,
      loaded_miles,
      deadhead_miles,
      estimated_tolls,
      gross_revenue,
      total_operating_cost,
      estimated_profit,
      profit_margin,
      revenue_per_loaded_mile,
      revenue_per_total_mile
    )
    VALUES
      (
        '00000000-0000-0000-0000-000000000601',
        '00000000-0000-0000-0000-000000000301',
        '00000000-0000-0000-0000-000000000401',
        '00000000-0000-0000-0000-000000000501',
        'HM-1042',
        'accepted',
        1800.00,
        250.00,
        100.00,
        510.00,
        35.00,
        90.00,
        2150.00,
        1245.62,
        904.38,
        0.4206,
        4.22,
        3.94
      ),
      (
        '00000000-0000-0000-0000-000000000602',
        '00000000-0000-0000-0000-000000000302',
        '00000000-0000-0000-0000-000000000402',
        '00000000-0000-0000-0000-000000000502',
        'HM-1042',
        'evaluating',
        900.00,
        100.00,
        0.00,
        200.00,
        10.00,
        25.00,
        1000.00,
        500.00,
        500.00,
        0.5000,
        5.00,
        4.76
      );

    INSERT INTO public.stops (
      id,
      user_id,
      load_id,
      kind,
      sequence,
      facility_name,
      appointment_starts_at,
      appointment_ends_at,
      appointment_timezone
    )
    VALUES (
      '00000000-0000-0000-0000-000000000701',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000601',
      'pickup',
      1,
      'Detroit Pickup',
      '2026-07-01 12:00:00+00',
      '2026-07-01 14:00:00+00',
      'America/Detroit'
    );
  $$,
  'valid load-to-cash seed graph can be inserted'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    INSERT INTO public.vehicles (
      user_id,
      equipment_name,
      fuel_economy_mpg,
      fuel_price_per_gallon,
      maintenance_reserve_per_mile,
      monthly_fixed_costs,
      estimated_working_miles
    )
    VALUES (
      '00000000-0000-0000-0000-000000000301',
      'Missing ID Truck',
      6.70,
      3.64,
      0.35,
      8400.00,
      11350.00
    )
  $$),
  '23502',
  'vehicle inserts require a client UUID'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    INSERT INTO public.loads (
      id,
      user_id,
      customer_id,
      reference_number,
      line_haul_rate,
      loaded_miles
    )
    VALUES (
      '00000000-0000-0000-0000-000000000603',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000502',
      'CROSS-USER',
      1000.00,
      100.00
    )
  $$),
  '23503',
  'loads cannot reference another user customer'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    INSERT INTO public.customers (
      id,
      user_id,
      name
    )
    VALUES (
      '00000000-0000-0000-0000-000000000503',
      '00000000-0000-0000-0000-000000000301',
      '   '
    )
  $$),
  '23514',
  'blank customer names are rejected'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    INSERT INTO public.loads (
      id,
      user_id,
      customer_id,
      reference_number,
      line_haul_rate,
      loaded_miles,
      deadhead_miles
    )
    VALUES (
      '00000000-0000-0000-0000-000000000604',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000501',
      'BAD-MILES',
      1000.00,
      100.00,
      -1.00
    )
  $$),
  '23514',
  'negative mileage is rejected'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    INSERT INTO public.stops (
      id,
      user_id,
      load_id,
      kind,
      sequence,
      facility_name,
      appointment_starts_at,
      appointment_ends_at,
      appointment_timezone
    )
    VALUES (
      '00000000-0000-0000-0000-000000000702',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000601',
      'delivery',
      2,
      'Columbus Delivery',
      '2026-07-01 16:00:00+00',
      '2026-07-01 15:00:00+00',
      'America/New_York'
    )
  $$),
  '23514',
  'appointment windows must end at or after start'
);

SELECT lives_ok(
  $$
    INSERT INTO public.trip_events (
      id,
      user_id,
      load_id,
      kind,
      status,
      from_status,
      to_status,
      occurred_at,
      timezone_identifier,
      location_source
    )
    VALUES (
      '00000000-0000-0000-0000-000000000801',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000601',
      'status_changed',
      'accepted',
      'evaluating',
      'accepted',
      '2026-07-01 11:00:00+00',
      'America/Detroit',
      'manual'
    )
  $$,
  'valid status trip event can be inserted'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    INSERT INTO public.trip_events (
      id,
      user_id,
      load_id,
      kind,
      status,
      occurred_at,
      timezone_identifier,
      location_source
    )
    VALUES (
      '00000000-0000-0000-0000-000000000802',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000601',
      'arrived',
      'accepted',
      '2026-07-01 12:00:00+00',
      'America/Detroit',
      'manual'
    )
  $$),
  '23514',
  'arrival events require a stop'
);

SELECT lives_ok(
  $$
    INSERT INTO public.trip_events (
      id,
      user_id,
      load_id,
      stop_id,
      kind,
      status,
      occurred_at,
      timezone_identifier,
      location_source,
      latitude,
      longitude,
      horizontal_accuracy_meters
    )
    VALUES (
      '00000000-0000-0000-0000-000000000803',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000601',
      '00000000-0000-0000-0000-000000000701',
      'arrived',
      'accepted',
      '2026-07-01 12:01:00+00',
      'America/Detroit',
      'device_verified',
      42.331400,
      -83.045800,
      12.50
    )
  $$,
  'valid device-verified stop event can be inserted'
);

SELECT is(
  pg_temp.capture_sqlstate($$
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
    VALUES (
      '00000000-0000-0000-0000-000000000804',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000601',
      '00000000-0000-0000-0000-000000000701',
      'departed',
      'accepted',
      '2026-07-01 12:30:00+00',
      'America/Detroit',
      'device_verified'
    )
  $$),
  '23514',
  'device location events require coordinates and accuracy'
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
      '00000000-0000-0000-0000-000000000901',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000601',
      'rate_confirmation',
      'rate-confirmation.pdf',
      'application/pdf',
      2048,
      repeat('a', 64),
      '00000000-0000-0000-0000-000000000301/00000000-0000-0000-0000-000000000601/00000000-0000-0000-0000-000000000901',
      'synced',
      '2026-07-01 12:00:00+00'
    )
  $$,
  'valid synced document metadata can be inserted'
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
      sha256_hex
    )
    VALUES (
      '00000000-0000-0000-0000-000000000902',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000601',
      'receipt',
      'receipt.pdf',
      'application/pdf',
      128,
      'not-a-sha'
    )
  $$),
  '23514',
  'document hashes must be lowercase sha256 hex when present'
);

SELECT lives_ok(
  $$
    INSERT INTO public.charges (
      id,
      user_id,
      load_id,
      source_trip_event_id,
      kind,
      description,
      amount
    )
    VALUES (
      '00000000-0000-0000-0000-000000001001',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000601',
      '00000000-0000-0000-0000-000000000803',
      'detention',
      'Pickup detention',
      125.00
    );

    INSERT INTO public.invoices (
      id,
      user_id,
      load_id,
      invoice_number,
      status,
      issued_at,
      due_at,
      total_amount,
      remaining_balance
    )
    VALUES (
      '00000000-0000-0000-0000-000000001101',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000601',
      'HM-1042',
      'sent',
      '2026-07-02 12:00:00+00',
      '2026-08-01 12:00:00+00',
      2150.00,
      2150.00
    );

    INSERT INTO public.invoice_revisions (
      id,
      user_id,
      invoice_id,
      revision_number,
      total_amount
    )
    VALUES (
      '00000000-0000-0000-0000-000000001201',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000001101',
      1,
      2150.00
    );

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
    VALUES (
      '00000000-0000-0000-0000-000000001301',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000001201',
      '00000000-0000-0000-0000-000000001001',
      '00000000-0000-0000-0000-000000000901',
      1,
      'detention',
      'Pickup detention',
      125.00
    );

    INSERT INTO public.payments (
      id,
      user_id,
      invoice_id,
      amount,
      received_at,
      method
    )
    VALUES (
      '00000000-0000-0000-0000-000000001401',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000001101',
      400.00,
      '2026-08-05 12:00:00+00',
      'ach'
    )
  $$,
  'valid invoice, immutable revision, evidence item, charge, and payment can be inserted'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    INSERT INTO public.invoices (
      id,
      user_id,
      load_id,
      invoice_number
    )
    VALUES (
      '00000000-0000-0000-0000-000000001102',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000601',
      'HM-1042'
    )
  $$),
  '23505',
  'invoice numbers are unique per user'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    INSERT INTO public.payments (
      id,
      user_id,
      invoice_id,
      amount,
      received_at
    )
    VALUES (
      '00000000-0000-0000-0000-000000001402',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000001101',
      0,
      '2026-08-05 12:00:00+00'
    )
  $$),
  '23514',
  'payments must be positive'
);

SELECT lives_ok(
  $$
    INSERT INTO public.tracking_shares (
      id,
      user_id,
      load_id,
      token_hash,
      expires_at
    )
    VALUES (
      '00000000-0000-0000-0000-000000001501',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000601',
      repeat('b', 64),
      now() + interval '72 hours'
    )
  $$,
  'valid tracking share metadata can be inserted'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    INSERT INTO public.tracking_shares (
      id,
      user_id,
      load_id,
      token_hash,
      expires_at
    )
    VALUES (
      '00000000-0000-0000-0000-000000001502',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000601',
      'too-short',
      now() + interval '72 hours'
    )
  $$),
  '23514',
  'tracking share token hashes must be hash-like values'
);

SELECT lives_ok(
  $$
    INSERT INTO public.eta_updates (
      id,
      user_id,
      load_id,
      stop_id,
      tracking_share_id,
      estimated_arrival_at,
      generated_at,
      source,
      stale_after_seconds,
      delay_reason
    )
    VALUES (
      '00000000-0000-0000-0000-000000001601',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000601',
      '00000000-0000-0000-0000-000000000701',
      '00000000-0000-0000-0000-000000001501',
      '2026-07-01 18:00:00+00',
      '2026-07-01 17:30:00+00',
      'manual',
      900,
      'Traffic near Columbus'
    )
  $$,
  'valid ETA update can be inserted'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    INSERT INTO public.eta_updates (
      id,
      user_id,
      load_id,
      estimated_arrival_at,
      generated_at,
      source
    )
    VALUES (
      '00000000-0000-0000-0000-000000001602',
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000601',
      '2026-07-01 17:00:00+00',
      '2026-07-01 17:30:00+00',
      'manual'
    )
  $$),
  '23514',
  'ETA cannot be earlier than its generated timestamp'
);

UPDATE public.loads
SET updated_at = '2020-01-01 00:00:00+00'
WHERE id = '00000000-0000-0000-0000-000000000601';

UPDATE public.loads
SET status = 'in_transit'
WHERE id = '00000000-0000-0000-0000-000000000601';

SELECT ok(
  (
    SELECT updated_at > '2020-01-01 00:00:00+00'::timestamp with time zone
    FROM public.loads
    WHERE id = '00000000-0000-0000-0000-000000000601'
  ),
  'updated_at refreshes on mutable load update'
);

DELETE FROM auth.users
WHERE id = '00000000-0000-0000-0000-000000000301';

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM public.loads
    WHERE user_id = '00000000-0000-0000-0000-000000000301'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.documents
    WHERE user_id = '00000000-0000-0000-0000-000000000301'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.invoices
    WHERE user_id = '00000000-0000-0000-0000-000000000301'
  ),
  'deleting an auth user cascades through load-to-cash rows'
);

SELECT * FROM finish();
ROLLBACK;
