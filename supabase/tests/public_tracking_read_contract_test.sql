BEGIN;
SET LOCAL search_path = public, extensions;

SELECT plan(23);

CREATE TEMP TABLE public_tracking_test_results (
  name text primary key,
  response jsonb
) ON COMMIT DROP;

GRANT SELECT, INSERT, UPDATE, DELETE ON public_tracking_test_results TO authenticated, service_role;

SELECT ok(
  has_function_privilege(
    'service_role',
    'public.read_public_tracking_share(text)',
    'execute'
  ),
  'service role can execute the public tracking read RPC'
);

SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.read_public_tracking_share(text)',
    'execute'
  ),
  'anonymous clients cannot execute the public tracking read RPC directly'
);

SELECT ok(
  NOT has_function_privilege(
    'authenticated',
    'public.read_public_tracking_share(text)',
    'execute'
  ),
  'authenticated clients cannot execute the public tracking read RPC directly'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'stops'
      AND column_name = 'city'
      AND data_type = 'text'
  ),
  'stops support optional public city locality'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'stops'
      AND column_name = 'region'
      AND data_type = 'text'
  ),
  'stops support optional public region locality'
);

INSERT INTO auth.users (id, email, aud, role, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-000000000411', 'be08-owner-a@example.com', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-0000-0000-000000000412', 'be08-owner-b@example.com', 'authenticated', 'authenticated', now(), now());

INSERT INTO public.business_profiles (
  user_id,
  legal_name,
  display_name,
  mailing_address,
  phone,
  invoice_email
)
VALUES
  (
    '00000000-0000-0000-0000-000000000411',
    'Public Tracking Alpha LLC',
    'Northstar Freight LLC',
    '100 Private Road, Detroit, MI 48201',
    '313-555-0411',
    'billing-be08-alpha@example.com'
  ),
  (
    '00000000-0000-0000-0000-000000000412',
    'Public Tracking Beta LLC',
    'Beta Freight LLC',
    '200 Private Road, Detroit, MI 48201',
    '313-555-0412',
    'billing-be08-beta@example.com'
  );

INSERT INTO public.customers (id, user_id, name, kind)
VALUES
  ('00000000-0000-0000-0000-000000000611', '00000000-0000-0000-0000-000000000411', 'Alpha Broker', 'broker'),
  ('00000000-0000-0000-0000-000000000612', '00000000-0000-0000-0000-000000000412', 'Beta Broker', 'broker');

INSERT INTO public.loads (
  id,
  user_id,
  customer_id,
  reference_number,
  status,
  line_haul_rate,
  fuel_surcharge,
  loaded_miles,
  deadhead_miles,
  updated_at
)
VALUES
  (
    '00000000-0000-0000-0000-000000000711',
    '00000000-0000-0000-0000-000000000411',
    '00000000-0000-0000-0000-000000000611',
    'BE08-ACTIVE',
    'in_transit',
    2400.00,
    250.00,
    300.00,
    20.00,
    now() - interval '10 minutes'
  ),
  (
    '00000000-0000-0000-0000-000000000712',
    '00000000-0000-0000-0000-000000000411',
    '00000000-0000-0000-0000-000000000611',
    'BE08-HIDDEN',
    'accepted',
    1800.00,
    0.00,
    200.00,
    12.00,
    now() - interval '8 minutes'
  );

INSERT INTO public.stops (
  id,
  user_id,
  load_id,
  kind,
  sequence,
  facility_name,
  address,
  city,
  region,
  appointment_starts_at,
  appointment_ends_at,
  appointment_timezone
)
VALUES
  (
    '00000000-0000-0000-0000-000000000811',
    '00000000-0000-0000-0000-000000000411',
    '00000000-0000-0000-0000-000000000711',
    'pickup',
    1,
    'Private Pickup Dock',
    '123 Hidden Street, Detroit, MI 48201',
    'Detroit',
    'MI',
    '2026-07-02 12:00:00+00',
    '2026-07-02 14:00:00+00',
    'America/Detroit'
  ),
  (
    '00000000-0000-0000-0000-000000000812',
    '00000000-0000-0000-0000-000000000411',
    '00000000-0000-0000-0000-000000000711',
    'delivery',
    2,
    'Public Delivery',
    '456 Hidden Avenue, Columbus, OH 43004',
    'Columbus',
    'OH',
    '2026-07-02 20:00:00+00',
    '2026-07-02 22:00:00+00',
    'America/New_York'
  ),
  (
    '00000000-0000-0000-0000-000000000813',
    '00000000-0000-0000-0000-000000000411',
    '00000000-0000-0000-0000-000000000712',
    'delivery',
    1,
    'Hidden Visibility Delivery',
    '789 Hidden Boulevard, Lansing, MI 48933',
    'Lansing',
    'MI',
    null,
    null,
    null
  );

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
VALUES
  (
    '00000000-0000-0000-0000-000000000821',
    '00000000-0000-0000-0000-000000000411',
    '00000000-0000-0000-0000-000000000711',
    '00000000-0000-0000-0000-000000000812',
    'arrived',
    'at_delivery',
    now() - interval '12 minutes',
    'America/New_York',
    'device_verified',
    39.961176,
    -82.998794,
    12.5
  );

INSERT INTO public.trip_events (
  id,
  user_id,
  load_id,
  stop_id,
  kind,
  status,
  from_status,
  to_status,
  occurred_at,
  timezone_identifier,
  location_source
)
VALUES
  (
    '00000000-0000-0000-0000-000000000822',
    '00000000-0000-0000-0000-000000000411',
    '00000000-0000-0000-0000-000000000711',
    null,
    'status_changed',
    'in_transit',
    'at_pickup',
    'in_transit',
    now() - interval '1 hour',
    'America/Detroit',
    'manual'
  );

INSERT INTO public.eta_updates (
  id,
  user_id,
  load_id,
  stop_id,
  estimated_arrival_at,
  generated_at,
  source,
  stale_after_seconds,
  delay_reason
)
VALUES
  (
    '00000000-0000-0000-0000-000000000831',
    '00000000-0000-0000-0000-000000000411',
    '00000000-0000-0000-0000-000000000711',
    '00000000-0000-0000-0000-000000000812',
    now() + interval '45 minutes',
    now() - interval '5 minutes',
    'on_device',
    900,
    'Waiting for dock assignment.'
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
VALUES (
  '00000000-0000-0000-0000-000000000841',
  '00000000-0000-0000-0000-000000000411',
  '00000000-0000-0000-0000-000000000711',
  'proof_of_delivery',
  'pod.pdf',
  'application/pdf',
  1024,
  repeat('a', 64),
  '00000000-0000-0000-0000-000000000411/00000000-0000-0000-0000-000000000711/00000000-0000-0000-0000-000000000841',
  'synced',
  now() - interval '4 minutes'
);

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000411';

INSERT INTO public_tracking_test_results (name, response)
SELECT
  'create visible share',
  public.create_tracking_share(
    '00000000-0000-0000-0000-000000000911',
    '00000000-0000-0000-0000-000000000711',
    'delivery',
    '{}'::jsonb,
    now() + interval '4 hours'
  );

INSERT INTO public_tracking_test_results (name, response)
SELECT
  'create hidden share',
  public.create_tracking_share(
    '00000000-0000-0000-0000-000000000912',
    '00000000-0000-0000-0000-000000000712',
    'all',
    jsonb_build_object(
      'show_carrier_name', false,
      'show_reference_number', false,
      'show_stops', false,
      'show_eta', false,
      'show_pod_availability', false
    ),
    now() + interval '4 hours'
  );

RESET ROLE;
SET LOCAL ROLE service_role;

INSERT INTO public_tracking_test_results (name, response)
SELECT
  'read visible share',
  public.read_public_tracking_share(
    (
      SELECT response ->> 'token'
      FROM public_tracking_test_results
      WHERE name = 'create visible share'
    )
  );

INSERT INTO public_tracking_test_results (name, response)
SELECT
  'read hidden share',
  public.read_public_tracking_share(
    (
      SELECT response ->> 'token'
      FROM public_tracking_test_results
      WHERE name = 'create hidden share'
    )
  );

SELECT is(
  (
    SELECT response ->> 'schemaVersion'
    FROM public_tracking_test_results
    WHERE name = 'read visible share'
  ),
  '1',
  'public tracking response declares schema version 1'
);

SELECT is(
  (
    SELECT response #>> '{carrier,displayName}'
    FROM public_tracking_test_results
    WHERE name = 'read visible share'
  ),
  'Northstar Freight LLC',
  'public tracking response includes the public carrier display name'
);

SELECT is(
  (
    SELECT response #>> '{load,referenceNumber}'
    FROM public_tracking_test_results
    WHERE name = 'read visible share'
  ),
  'BE08-ACTIVE',
  'public tracking response includes the load reference when visible'
);

SELECT is(
  (
    SELECT response #>> '{load,status}'
    FROM public_tracking_test_results
    WHERE name = 'read visible share'
  ),
  'delayed',
  'public tracking response maps load and delay state to the public status enum'
);

SELECT is(
  (
    SELECT jsonb_array_length(response -> 'stops')
    FROM public_tracking_test_results
    WHERE name = 'read visible share'
  ),
  1,
  'delivery-scoped public tracking response returns only delivery stops'
);

SELECT is(
  (
    SELECT response #>> '{stops,0,city}'
    FROM public_tracking_test_results
    WHERE name = 'read visible share'
  ),
  'Columbus',
  'public tracking response includes structured public stop locality'
);

SELECT is(
  (
    SELECT response #>> '{eta,source}'
    FROM public_tracking_test_results
    WHERE name = 'read visible share'
  ),
  'on_device_estimate',
  'public tracking response maps ETA source to the web contract'
);

SELECT is(
  (
    SELECT response #>> '{latestDelay,reason}'
    FROM public_tracking_test_results
    WHERE name = 'read visible share'
  ),
  'Waiting for dock assignment.',
  'public tracking response includes the latest approved delay reason'
);

SELECT ok(
  (
    SELECT (response #>> '{pod,available}')::boolean
    FROM public_tracking_test_results
    WHERE name = 'read visible share'
  ),
  'public tracking response reports POD availability without exposing document data'
);

SELECT ok(
  (
    SELECT response::text !~* 'token|token_hash|line_haul|rate|fuel_surcharge|amount|invoice|payment|object_key|signed|latitude|longitude|accuracy|address|user_id|auth|session|credential'
    FROM public_tracking_test_results
    WHERE name = 'read visible share'
  ),
  'public tracking response omits token, financial, coordinate, address, document, account, and auth fields'
);

SELECT is(
  (
    SELECT jsonb_array_length(response -> 'events')
    FROM public_tracking_test_results
    WHERE name = 'read visible share'
  ),
  4,
  'public tracking response includes approved trip and ETA events only'
);

SELECT is(
  (
    SELECT response #>> '{carrier,displayName}'
    FROM public_tracking_test_results
    WHERE name = 'read hidden share'
  ),
  'Carrier',
  'visibility settings can hide carrier identity'
);

SELECT is(
  (
    SELECT response #>> '{load,referenceNumber}'
    FROM public_tracking_test_results
    WHERE name = 'read hidden share'
  ),
  '',
  'visibility settings can hide the load reference'
);

SELECT is(
  (
    SELECT jsonb_array_length(response -> 'stops')
    FROM public_tracking_test_results
    WHERE name = 'read hidden share'
  ),
  0,
  'visibility settings can hide stops'
);

SELECT is(
  (
    SELECT response #>> '{eta,status}'
    FROM public_tracking_test_results
    WHERE name = 'read hidden share'
  ),
  'unavailable',
  'visibility settings can hide ETA'
);

SELECT ok(
  (
    SELECT NOT (response #>> '{pod,available}')::boolean
    FROM public_tracking_test_results
    WHERE name = 'read hidden share'
  ),
  'visibility settings can hide POD availability'
);

SELECT is(
  public.read_public_tracking_share('not-a-real-share-token'),
  null::jsonb,
  'invalid tokens return no public tracking response'
);

UPDATE public.tracking_shares
SET revoked_at = now()
WHERE id = '00000000-0000-0000-0000-000000000911';

SELECT is(
  public.read_public_tracking_share(
    (
      SELECT response ->> 'token'
      FROM public_tracking_test_results
      WHERE name = 'create visible share'
    )
  ),
  null::jsonb,
  'revoked tokens return no public tracking response'
);

SELECT * FROM finish();
ROLLBACK;
