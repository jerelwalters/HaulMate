BEGIN;
SET LOCAL search_path = public, extensions;

SELECT plan(24);

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

CREATE TEMP TABLE tracking_share_test_results (
  name text primary key,
  response jsonb not null
) ON COMMIT DROP;

GRANT SELECT, INSERT, UPDATE, DELETE ON tracking_share_test_results TO authenticated;

SELECT ok(
  EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'tracking_shares'
      AND column_name = 'stop_scope'
      AND data_type = 'text'
      AND is_nullable = 'NO'
  ),
  'tracking_shares stores pickup/delivery/all stop scope'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'tracking_shares'
      AND column_name = 'expires_at'
      AND is_nullable = 'YES'
  ),
  'tracking_shares allows null expires_at for delivery-based default expiry'
);

SELECT ok(
  NOT has_function_privilege(
    'authenticated',
    'app_private.hash_tracking_share_token(text)',
    'execute'
  ),
  'authenticated clients cannot call the private token hash helper'
);

SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.create_tracking_share(uuid,uuid,text,jsonb,timestamp with time zone)',
    'execute'
  ),
  'authenticated clients can create tracking shares through the lifecycle RPC'
);

SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.create_tracking_share(uuid,uuid,text,jsonb,timestamp with time zone)',
    'execute'
  ),
  'anonymous clients cannot create tracking shares'
);

SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.preview_tracking_share(uuid)',
    'execute'
  ),
  'authenticated clients can preview owned tracking shares'
);

SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.shorten_tracking_share_expiry(uuid,timestamp with time zone)',
    'execute'
  ),
  'authenticated clients can shorten owned tracking-share expiry'
);

SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.revoke_tracking_share(uuid)',
    'execute'
  ),
  'authenticated clients can revoke owned tracking shares'
);

INSERT INTO auth.users (id, email, aud, role, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-000000000401', 'be07-owner-a@example.com', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-0000-0000-000000000402', 'be07-owner-b@example.com', 'authenticated', 'authenticated', now(), now());

INSERT INTO public.business_profiles (
  user_id,
  legal_name,
  mailing_address,
  phone,
  invoice_email
)
VALUES
  (
    '00000000-0000-0000-0000-000000000401',
    'Tracking Alpha LLC',
    '100 Tracking Road, Detroit, MI 48201',
    '313-555-0401',
    'billing-tracking-alpha@example.com'
  ),
  (
    '00000000-0000-0000-0000-000000000402',
    'Tracking Beta LLC',
    '200 Tracking Road, Detroit, MI 48201',
    '313-555-0402',
    'billing-tracking-beta@example.com'
  );

INSERT INTO public.customers (id, user_id, name, kind)
VALUES
  ('00000000-0000-0000-0000-000000000601', '00000000-0000-0000-0000-000000000401', 'Alpha Tracking Broker', 'broker'),
  ('00000000-0000-0000-0000-000000000602', '00000000-0000-0000-0000-000000000402', 'Beta Tracking Broker', 'broker');

INSERT INTO public.loads (
  id,
  user_id,
  customer_id,
  reference_number,
  status,
  line_haul_rate,
  loaded_miles,
  delivered_at
)
VALUES
  (
    '00000000-0000-0000-0000-000000000701',
    '00000000-0000-0000-0000-000000000401',
    '00000000-0000-0000-0000-000000000601',
    'BE07-ACTIVE',
    'in_transit',
    1000.00,
    100.00,
    null
  ),
  (
    '00000000-0000-0000-0000-000000000702',
    '00000000-0000-0000-0000-000000000401',
    '00000000-0000-0000-0000-000000000601',
    'BE07-DELIVERED',
    'delivered',
    1000.00,
    100.00,
    now() - interval '1 hour'
  ),
  (
    '00000000-0000-0000-0000-000000000703',
    '00000000-0000-0000-0000-000000000401',
    '00000000-0000-0000-0000-000000000601',
    'BE07-STALE',
    'delivered',
    1000.00,
    100.00,
    now() - interval '80 hours'
  ),
  (
    '00000000-0000-0000-0000-000000000704',
    '00000000-0000-0000-0000-000000000402',
    '00000000-0000-0000-0000-000000000602',
    'BE07-BETA',
    'in_transit',
    1000.00,
    100.00,
    null
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
VALUES
  (
    '00000000-0000-0000-0000-000000000801',
    '00000000-0000-0000-0000-000000000401',
    '00000000-0000-0000-0000-000000000701',
    'pickup',
    1,
    'Alpha Pickup',
    '2026-07-02 12:00:00+00',
    '2026-07-02 14:00:00+00',
    'America/Detroit'
  ),
  (
    '00000000-0000-0000-0000-000000000802',
    '00000000-0000-0000-0000-000000000401',
    '00000000-0000-0000-0000-000000000701',
    'delivery',
    2,
    'Alpha Delivery',
    '2026-07-02 20:00:00+00',
    '2026-07-02 22:00:00+00',
    'America/New_York'
  );

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000401';

INSERT INTO tracking_share_test_results (name, response)
SELECT
  'create active delivery share',
  public.create_tracking_share(
    '00000000-0000-0000-0000-000000000901',
    '00000000-0000-0000-0000-000000000701',
    'delivery',
    jsonb_build_object('show_pod_availability', false),
    null
  );

SELECT ok(
  (
    SELECT (response ->> 'token') ~ '^[A-Za-z0-9_-]{43}$'
    FROM tracking_share_test_results
    WHERE name = 'create active delivery share'
  ),
  'create returns one URL-safe token with at least 256 bits of entropy'
);

SELECT is(
  (
    SELECT (response ->> 'token_bits')::integer
    FROM tracking_share_test_results
    WHERE name = 'create active delivery share'
  ),
  256,
  'create response declares 256 token bits'
);

SELECT ok(
  (
    SELECT NOT (response ? 'token_hash')
    FROM tracking_share_test_results
    WHERE name = 'create active delivery share'
  ),
  'create response does not expose the stored token hash'
);

SELECT ok(
  (
    SELECT
      ts.token_hash ~ '^[0-9a-f]{64}$'
      AND ts.token_hash <> (r.response ->> 'token')
    FROM public.tracking_shares ts
    JOIN tracking_share_test_results r
      ON r.name = 'create active delivery share'
    WHERE ts.id = '00000000-0000-0000-0000-000000000901'
  ),
  'tracking share persists only a hash-like value, not the plaintext token'
);

SELECT ok(
  (
    SELECT expires_at IS NULL
    FROM public.tracking_shares
    WHERE id = '00000000-0000-0000-0000-000000000901'
  ),
  'undelivered load share keeps null expires_at for the 72-hours-after-delivery default'
);

INSERT INTO tracking_share_test_results (name, response)
SELECT
  'preview active delivery share',
  public.preview_tracking_share('00000000-0000-0000-0000-000000000901');

SELECT ok(
  (
    SELECT NOT (response ? 'token') AND NOT (response ? 'token_hash')
    FROM tracking_share_test_results
    WHERE name = 'preview active delivery share'
  ),
  'preview response omits token material'
);

SELECT ok(
  (
    SELECT
      jsonb_array_length(response -> 'visible_stops') = 1
      AND response #>> '{visible_stops,0,kind}' = 'delivery'
    FROM tracking_share_test_results
    WHERE name = 'preview active delivery share'
  ),
  'delivery-scoped preview includes only delivery stops'
);

SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000402';

SELECT is(
  pg_temp.capture_sqlstate($$
    SELECT public.preview_tracking_share('00000000-0000-0000-0000-000000000901')
  $$),
  '42501',
  'another authenticated user cannot preview the share'
);

SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000401';

INSERT INTO tracking_share_test_results (name, response)
SELECT
  'shorten active delivery share',
  public.shorten_tracking_share_expiry(
    '00000000-0000-0000-0000-000000000901',
    now() + interval '2 hours'
  );

SELECT ok(
  (
    SELECT
      response ->> 'state' = 'active'
      AND (response ->> 'expires_at') IS NOT NULL
    FROM tracking_share_test_results
    WHERE name = 'shorten active delivery share'
  ),
  'shorten expiry keeps the share active with a fixed shortened expiry'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    SELECT public.shorten_tracking_share_expiry(
      '00000000-0000-0000-0000-000000000901',
      now() + interval '3 hours'
    )
  $$),
  '22023',
  'shorten expiry does not allow extending the current effective expiry'
);

INSERT INTO tracking_share_test_results (name, response)
SELECT
  'revoke active delivery share',
  public.revoke_tracking_share('00000000-0000-0000-0000-000000000901');

SELECT is(
  (
    SELECT response ->> 'state'
    FROM tracking_share_test_results
    WHERE name = 'revoke active delivery share'
  ),
  'revoked',
  'revoke response marks the share revoked'
);

SELECT ok(
  (
    SELECT revoked_at IS NOT NULL
    FROM public.tracking_shares
    WHERE id = '00000000-0000-0000-0000-000000000901'
  ),
  'revoke persists revoked_at immediately'
);

INSERT INTO tracking_share_test_results (name, response)
SELECT
  'create delivered share',
  public.create_tracking_share(
    '00000000-0000-0000-0000-000000000902',
    '00000000-0000-0000-0000-000000000702',
    'all',
    '{}'::jsonb,
    null
  );

SELECT is(
  (
    SELECT ts.expires_at::text
    FROM public.tracking_shares ts
    WHERE ts.id = '00000000-0000-0000-0000-000000000902'
  ),
  (
    SELECT (l.delivered_at + interval '72 hours')::text
    FROM public.loads l
    WHERE l.id = '00000000-0000-0000-0000-000000000702'
  ),
  'delivered load share stores the default 72-hours-after-delivery expiry'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    SELECT public.create_tracking_share(
      '00000000-0000-0000-0000-000000000903',
      '00000000-0000-0000-0000-000000000703',
      'all',
      '{}'::jsonb,
      null
    )
  $$),
  '22023',
  'create rejects a delivered load whose default tracking window already expired'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    SELECT public.create_tracking_share(
      '00000000-0000-0000-0000-000000000904',
      '00000000-0000-0000-0000-000000000701',
      'warehouse',
      '{}'::jsonb,
      null
    )
  $$),
  '22023',
  'create rejects invalid stop scope values'
);

SELECT is(
  pg_temp.capture_sqlstate($$
    SELECT public.create_tracking_share(
      '00000000-0000-0000-0000-000000000905',
      '00000000-0000-0000-0000-000000000704',
      'all',
      '{}'::jsonb,
      null
    )
  $$),
  '42501',
  'create rejects loads owned by another authenticated user'
);

SELECT * FROM finish();
ROLLBACK;
