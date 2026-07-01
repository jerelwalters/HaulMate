BEGIN;
SET LOCAL search_path = public, extensions;

SELECT plan(21);

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

CREATE TEMP TABLE sync_test_results (
  name text primary key,
  response jsonb not null
) ON COMMIT DROP;

GRANT SELECT, INSERT, UPDATE, DELETE ON sync_test_results TO authenticated;

INSERT INTO auth.users (id, email, aud, role, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-000000000391', 'be06-owner-a@example.com', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-0000-0000-000000000392', 'be06-owner-b@example.com', 'authenticated', 'authenticated', now(), now());

INSERT INTO public.business_profiles (
  user_id,
  legal_name,
  mailing_address,
  phone,
  invoice_email
)
VALUES
  (
    '00000000-0000-0000-0000-000000000391',
    'Alpha Sync LLC',
    '100 Alpha Road, Detroit, MI 48201',
    '313-555-0391',
    'billing-alpha-sync@example.com'
  ),
  (
    '00000000-0000-0000-0000-000000000392',
    'Beta Sync LLC',
    '200 Beta Road, Detroit, MI 48201',
    '313-555-0392',
    'billing-beta-sync@example.com'
  );

INSERT INTO public.customers (id, user_id, name, kind)
VALUES
  ('00000000-0000-0000-0000-000000000591', '00000000-0000-0000-0000-000000000391', 'Alpha Sync Broker', 'broker'),
  ('00000000-0000-0000-0000-000000000592', '00000000-0000-0000-0000-000000000392', 'Beta Sync Broker', 'broker');

INSERT INTO public.loads (
  id,
  user_id,
  customer_id,
  reference_number,
  status,
  line_haul_rate,
  fuel_surcharge,
  accessorial_revenue,
  loaded_miles,
  deadhead_miles,
  estimated_tolls
)
VALUES
  (
    '00000000-0000-0000-0000-000000000692',
    '00000000-0000-0000-0000-000000000391',
    '00000000-0000-0000-0000-000000000591',
    'STALE-SERVER',
    'accepted',
    1100.00,
    100.00,
    0.00,
    210.00,
    10.00,
    25.00
  ),
  (
    '00000000-0000-0000-0000-000000000693',
    '00000000-0000-0000-0000-000000000391',
    '00000000-0000-0000-0000-000000000591',
    'BAD-STATE',
    'accepted',
    1200.00,
    100.00,
    0.00,
    220.00,
    10.00,
    25.00
  ),
  (
    '00000000-0000-0000-0000-000000000694',
    '00000000-0000-0000-0000-000000000391',
    '00000000-0000-0000-0000-000000000591',
    'FIN-CONFLICT',
    'invoiced',
    1000.00,
    100.00,
    0.00,
    200.00,
    10.00,
    25.00
  );

SELECT has_table('public', 'sync_operations', 'sync operation replay ledger exists');

SELECT ok(
  NOT has_table_privilege('authenticated', 'public.sync_operations', 'insert'),
  'authenticated clients cannot forge sync operation ledger rows'
);

SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.apply_load_sync_operation(uuid,text,jsonb,timestamp with time zone)',
    'execute'
  ),
  'authenticated clients can execute the load sync RPC'
);

SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.apply_load_sync_operation(uuid,text,jsonb,timestamp with time zone)',
    'execute'
  ),
  'anonymous clients cannot execute the load sync RPC'
);

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000391';

INSERT INTO sync_test_results (name, response)
SELECT
  'initial load upsert',
  public.apply_load_sync_operation(
    '00000000-0000-0000-0000-000000000901',
    'be06-load-000000000691-v1',
    jsonb_build_object(
      'id', '00000000-0000-0000-0000-000000000691',
      'customer_id', '00000000-0000-0000-0000-000000000591',
      'reference_number', 'SYNC-691',
      'status', 'accepted',
      'line_haul_rate', 1250.00,
      'fuel_surcharge', 150.00,
      'accessorial_revenue', 25.00,
      'loaded_miles', 250.00,
      'deadhead_miles', 15.00,
      'estimated_tolls', 30.00,
      'gross_revenue', 1425.00,
      'total_operating_cost', 700.00,
      'estimated_profit', 725.00,
      'profit_margin', 0.5088,
      'revenue_per_loaded_mile', 5.70,
      'revenue_per_total_mile', 5.38
    ),
    null
  );

SELECT is(
  (SELECT response ->> 'result' FROM sync_test_results WHERE name = 'initial load upsert'),
  'applied',
  'new load sync operation is applied'
);

SELECT is(
  (SELECT reference_number FROM public.loads WHERE id = '00000000-0000-0000-0000-000000000691'),
  'SYNC-691',
  'load sync operation writes the client UUID row'
);

SELECT ok(
  (SELECT response #>> '{reconciliation,server_updated_at}' IS NOT NULL FROM sync_test_results WHERE name = 'initial load upsert'),
  'load sync response exposes server reconciliation metadata'
);

INSERT INTO sync_test_results (name, response)
SELECT
  'retry load upsert',
  public.apply_load_sync_operation(
    '00000000-0000-0000-0000-000000000901',
    'be06-load-000000000691-v1',
    jsonb_build_object(
      'id', '00000000-0000-0000-0000-000000000691',
      'customer_id', '00000000-0000-0000-0000-000000000591',
      'reference_number', 'SYNC-691',
      'status', 'accepted',
      'line_haul_rate', 1250.00,
      'fuel_surcharge', 150.00,
      'accessorial_revenue', 25.00,
      'loaded_miles', 250.00,
      'deadhead_miles', 15.00,
      'estimated_tolls', 30.00,
      'gross_revenue', 1425.00,
      'total_operating_cost', 700.00,
      'estimated_profit', 725.00,
      'profit_margin', 0.5088,
      'revenue_per_loaded_mile', 5.70,
      'revenue_per_total_mile', 5.38
    ),
    null
  );

SELECT is(
  (SELECT response::text FROM sync_test_results WHERE name = 'retry load upsert'),
  (SELECT response::text FROM sync_test_results WHERE name = 'initial load upsert'),
  'retry with the same idempotency key returns the stable server result'
);

SELECT ok(
  (
    SELECT last_replayed_at IS NOT NULL
    FROM public.sync_operations
    WHERE idempotency_key = 'be06-load-000000000691-v1'
  ),
  'retry updates ledger replay metadata without changing the response'
);

SELECT is(
  pg_temp.capture_sqlstate($statement$
    SELECT public.apply_load_sync_operation(
      '00000000-0000-0000-0000-000000000902',
      'be06-load-000000000691-v1',
      jsonb_build_object(
        'id', '00000000-0000-0000-0000-000000000691',
        'customer_id', '00000000-0000-0000-0000-000000000591',
        'reference_number', 'SYNC-691',
        'status', 'accepted',
        'line_haul_rate', 1300.00,
        'loaded_miles', 250.00
      ),
      null
    )
  $statement$),
  '22023',
  'same idempotency key cannot be reused for a different payload'
);

INSERT INTO sync_test_results (name, response)
SELECT
  'stale update',
  public.apply_load_sync_operation(
    '00000000-0000-0000-0000-000000000903',
    'be06-load-000000000692-stale',
    jsonb_build_object(
      'id', '00000000-0000-0000-0000-000000000692',
      'customer_id', '00000000-0000-0000-0000-000000000591',
      'reference_number', 'STALE-CLIENT',
      'status', 'accepted',
      'line_haul_rate', 1100.00,
      'fuel_surcharge', 100.00,
      'accessorial_revenue', 0.00,
      'loaded_miles', 210.00,
      'deadhead_miles', 10.00,
      'estimated_tolls', 25.00
    ),
    '2026-01-01 00:00:00+00'
  );

SELECT is(
  (SELECT response ->> 'result' FROM sync_test_results WHERE name = 'stale update'),
  'rejected',
  'stale expected server timestamp is rejected'
);

SELECT is(
  (SELECT response ->> 'error_code' FROM sync_test_results WHERE name = 'stale update'),
  'stale_server_record',
  'stale response names the reconciliation error'
);

SELECT is(
  (SELECT reference_number FROM public.loads WHERE id = '00000000-0000-0000-0000-000000000692'),
  'STALE-SERVER',
  'stale update does not partially mutate the load'
);

INSERT INTO sync_test_results (name, response)
SELECT
  'invalid transition',
  public.apply_load_sync_operation(
    '00000000-0000-0000-0000-000000000904',
    'be06-load-000000000693-invalid-transition',
    jsonb_build_object(
      'id', '00000000-0000-0000-0000-000000000693',
      'customer_id', '00000000-0000-0000-0000-000000000591',
      'reference_number', 'BAD-STATE',
      'status', 'evaluating',
      'line_haul_rate', 1200.00,
      'fuel_surcharge', 100.00,
      'accessorial_revenue', 0.00,
      'loaded_miles', 220.00,
      'deadhead_miles', 10.00,
      'estimated_tolls', 25.00
    ),
    null
  );

SELECT is(
  (SELECT response ->> 'error_code' FROM sync_test_results WHERE name = 'invalid transition'),
  'invalid_status_transition',
  'invalid load state transition is rejected'
);

SELECT is(
  (SELECT status FROM public.loads WHERE id = '00000000-0000-0000-0000-000000000693'),
  'accepted',
  'invalid load state transition does not change server state'
);

INSERT INTO sync_test_results (name, response)
SELECT
  'financial conflict',
  public.apply_load_sync_operation(
    '00000000-0000-0000-0000-000000000905',
    'be06-load-000000000694-financial-conflict',
    jsonb_build_object(
      'id', '00000000-0000-0000-0000-000000000694',
      'customer_id', '00000000-0000-0000-0000-000000000591',
      'reference_number', 'FIN-CONFLICT',
      'status', 'invoiced',
      'line_haul_rate', 999.00,
      'fuel_surcharge', 100.00,
      'accessorial_revenue', 0.00,
      'loaded_miles', 200.00,
      'deadhead_miles', 10.00,
      'estimated_tolls', 25.00
    ),
    null
  );

SELECT is(
  (SELECT response ->> 'error_code' FROM sync_test_results WHERE name = 'financial conflict'),
  'financial_conflict',
  'financial edits to invoiced loads are rejected for user review'
);

SELECT is(
  (SELECT line_haul_rate::text FROM public.loads WHERE id = '00000000-0000-0000-0000-000000000694'),
  '1000.00',
  'financial conflict does not partially mutate money fields'
);

SELECT is(
  pg_temp.capture_sqlstate($statement$
    INSERT INTO public.sync_operations (
      id,
      user_id,
      idempotency_key,
      operation_type,
      target_table,
      target_id,
      request_hash,
      result_status,
      response
    )
    VALUES (
      '00000000-0000-0000-0000-000000000999',
      '00000000-0000-0000-0000-000000000391',
      'forged-ledger-row',
      'load.upsert',
      'loads',
      '00000000-0000-0000-0000-000000000691',
      repeat('a', 32),
      'applied',
      jsonb_build_object('result', 'applied')
    )
  $statement$),
  '42501',
  'authenticated clients cannot insert sync ledger rows directly'
);

SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000392';

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.sync_operations
    WHERE idempotency_key like 'be06-load-%'
  ),
  0,
  'User B cannot read User A sync operation ledger rows'
);

INSERT INTO sync_test_results (name, response)
SELECT
  'user b load upsert',
  public.apply_load_sync_operation(
    '00000000-0000-0000-0000-000000000906',
    'be06-load-000000000695-user-b',
    jsonb_build_object(
      'id', '00000000-0000-0000-0000-000000000695',
      'customer_id', '00000000-0000-0000-0000-000000000592',
      'reference_number', 'B-SYNC-695',
      'status', 'accepted',
      'line_haul_rate', 900.00,
      'loaded_miles', 180.00
    ),
    null
  );

SELECT is(
  (SELECT response ->> 'result' FROM sync_test_results WHERE name = 'user b load upsert'),
  'applied',
  'User B can apply their own idempotent sync operation'
);

SELECT is(
  pg_temp.capture_sqlstate($statement$
    SELECT public.apply_load_sync_operation(
      '00000000-0000-0000-0000-000000000907',
      'be06-load-user-b-cross-customer',
      jsonb_build_object(
        'id', '00000000-0000-0000-0000-000000000696',
        'customer_id', '00000000-0000-0000-0000-000000000591',
        'reference_number', 'B-CROSS-CUSTOMER',
        'status', 'accepted',
        'line_haul_rate', 900.00,
        'loaded_miles', 180.00
      ),
      null
    )
  $statement$),
  '23503',
  'sync operation cannot attach a load to another user customer'
);

SELECT * FROM finish();
ROLLBACK;
