-- P0-BE-08: Public tracking read contract.
--
-- Broker tracking is intentionally narrower than the owned backend schema.
-- The browser sends only the share token to the public Edge Function; the
-- function calls read_public_tracking_share with the service role and receives
-- an already-filtered JSON payload with no token, financial, coordinate,
-- private document, address, auth, account, or other-load fields.

alter table public.stops
  add column city text,
  add column region text,
  add constraint stops_city_length
    check (city is null or char_length(btrim(city)) <= 120),
  add constraint stops_region_length
    check (region is null or char_length(btrim(region)) <= 80);

comment on column public.stops.city is
  'Optional public stop locality for broker tracking responses; raw addresses stay private.';
comment on column public.stops.region is
  'Optional public stop region/state for broker tracking responses; raw addresses stay private.';

create or replace function app_private.public_tracking_load_status(
  p_status text,
  p_has_delay boolean
)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select case
    when p_status in ('delivered', 'invoiced', 'paid', 'disputed') then 'delivered'
    when p_status = 'cancelled' then 'cancelled'
    when p_has_delay then 'delayed'
    when p_status = 'en_route_to_pickup' then 'en_route_to_pickup'
    when p_status = 'at_pickup' then 'at_pickup'
    when p_status = 'in_transit' then 'en_route_to_delivery'
    when p_status = 'at_delivery' then 'at_delivery'
    else 'not_started'
  end;
$$;

comment on function app_private.public_tracking_load_status(text, boolean) is
  'Maps owned load states to the approved public tracking status enum.';

revoke execute on function app_private.public_tracking_load_status(text, boolean) from public, anon, authenticated;

create or replace function public.read_public_tracking_share(p_token text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with normalized_token as (
    select nullif(btrim(p_token), '') as value
  ),
  active_share as (
    select
      ts.id as share_id,
      ts.user_id,
      ts.load_id,
      ts.stop_scope,
      ts.show_carrier_name,
      ts.show_reference_number,
      ts.show_stops,
      ts.show_eta,
      ts.show_pod_availability,
      ts.expires_at,
      ts.revoked_at,
      l.reference_number,
      l.status as load_status,
      l.delivered_at,
      l.updated_at as load_updated_at,
      bp.legal_name,
      bp.display_name
    from normalized_token nt
    join public.tracking_shares ts
      on ts.token_hash = app_private.hash_tracking_share_token(nt.value)
    join public.loads l
      on l.user_id = ts.user_id
     and l.id = ts.load_id
    join public.business_profiles bp
      on bp.user_id = ts.user_id
    where nt.value is not null
      and app_private.tracking_share_state(ts.expires_at, ts.revoked_at, l.delivered_at) = 'active'
    limit 1
  ),
  latest_eta as (
    select e.*
    from public.eta_updates e
    join active_share a
      on a.user_id = e.user_id
     and a.load_id = e.load_id
    where e.tracking_share_id is null
       or e.tracking_share_id = a.share_id
    order by
      case when e.tracking_share_id = a.share_id then 0 else 1 end,
      e.generated_at desc
    limit 1
  ),
  visible_stops as (
    select s.*
    from public.stops s
    join active_share a
      on a.user_id = s.user_id
     and a.load_id = s.load_id
    where a.show_stops
      and s.kind in ('pickup', 'delivery')
      and (
        a.stop_scope = 'all'
        or s.kind = a.stop_scope
      )
  ),
  freshness as (
    select
      greatest(
        a.load_updated_at,
        coalesce((select max(s.updated_at) from public.stops s where s.user_id = a.user_id and s.load_id = a.load_id), '-infinity'::timestamp with time zone),
        coalesce((select max(t.updated_at) from public.trip_events t where t.user_id = a.user_id and t.load_id = a.load_id), '-infinity'::timestamp with time zone),
        coalesce((select max(e.updated_at) from public.eta_updates e where e.user_id = a.user_id and e.load_id = a.load_id), '-infinity'::timestamp with time zone),
        coalesce((select max(d.updated_at) from public.documents d where d.user_id = a.user_id and d.load_id = a.load_id and d.kind = 'proof_of_delivery'), '-infinity'::timestamp with time zone)
      ) as last_updated_at
    from active_share a
  ),
  pod_availability as (
    select
      coalesce(max(coalesce(d.uploaded_at, d.updated_at, d.created_at)), null) as available_at
    from public.documents d
    join active_share a
      on a.user_id = d.user_id
     and a.load_id = d.load_id
    where a.show_pod_availability
      and d.kind = 'proof_of_delivery'
      and d.sync_state = 'synced'
  ),
  current_stop as (
    select vs.id
    from visible_stops vs
    where exists (
        select 1
        from public.trip_events t
        where t.user_id = vs.user_id
          and t.load_id = vs.load_id
          and t.stop_id = vs.id
          and t.kind = 'arrived'
      )
      and not exists (
        select 1
        from public.trip_events t
        where t.user_id = vs.user_id
          and t.load_id = vs.load_id
          and t.stop_id = vs.id
          and t.kind = 'departed'
      )
    order by vs.sequence
    limit 1
  ),
  next_stop as (
    select vs.id
    from visible_stops vs
    where not exists (
        select 1
        from public.trip_events t
        where t.user_id = vs.user_id
          and t.load_id = vs.load_id
          and t.stop_id = vs.id
          and t.kind = 'departed'
      )
      and not exists (
        select 1
        from public.trip_events t
        where t.user_id = vs.user_id
          and t.load_id = vs.load_id
          and t.stop_id = vs.id
          and t.kind = 'status_changed'
          and t.to_status in ('delivered', 'invoiced', 'paid')
      )
    order by vs.sequence
    limit 1
  )
  select case
    when not exists (select 1 from active_share) then null
    else (
      select jsonb_build_object(
        'schemaVersion', 1,
        'carrier', jsonb_build_object(
          'displayName',
            case
              when a.show_carrier_name then coalesce(nullif(btrim(a.display_name), ''), a.legal_name)
              else 'Carrier'
            end
        ),
        'load', jsonb_build_object(
          'referenceNumber', case when a.show_reference_number then a.reference_number else '' end,
          'status', app_private.public_tracking_load_status(
            a.load_status,
            a.show_eta
              and exists (
                select 1
                from latest_eta le
                where nullif(btrim(le.delay_reason), '') is not null
              )
          ),
          'currentStopId', (select id::text from current_stop),
          'nextStopId', (select id::text from next_stop)
        ),
        'stops',
          coalesce(
            (
              select jsonb_agg(
                jsonb_build_object(
                  'id', vs.id::text,
                  'kind', vs.kind,
                  'displayName', vs.facility_name,
                  'city', coalesce(vs.city, ''),
                  'region', coalesce(vs.region, ''),
                  'appointmentWindow',
                    case
                      when vs.appointment_starts_at is not null
                        and vs.appointment_ends_at is not null
                        and vs.appointment_timezone is not null
                      then jsonb_build_object(
                        'startsAt', vs.appointment_starts_at,
                        'endsAt', vs.appointment_ends_at,
                        'timezone', vs.appointment_timezone,
                        'displayText', concat(
                          to_char(vs.appointment_starts_at at time zone vs.appointment_timezone, 'Mon FMDD, FMHH12:MI AM'),
                          '-',
                          to_char(vs.appointment_ends_at at time zone vs.appointment_timezone, 'FMHH12:MI AM'),
                          ' ',
                          vs.appointment_timezone
                        )
                      )
                      else null
                    end,
                  'status',
                    case
                      when exists (
                        select 1
                        from public.trip_events t
                        where t.user_id = vs.user_id
                          and t.load_id = vs.load_id
                          and t.stop_id = vs.id
                          and t.kind = 'departed'
                      )
                      or (
                        vs.kind = 'delivery'
                        and a.load_status in ('delivered', 'invoiced', 'paid', 'disputed')
                      )
                      then 'completed'
                      when exists (
                        select 1
                        from public.trip_events t
                        where t.user_id = vs.user_id
                          and t.load_id = vs.load_id
                          and t.stop_id = vs.id
                          and t.kind = 'arrived'
                      )
                      then 'arrived'
                      else 'pending'
                    end,
                  'arrivedAt',
                    (
                      select min(t.occurred_at)
                      from public.trip_events t
                      where t.user_id = vs.user_id
                        and t.load_id = vs.load_id
                        and t.stop_id = vs.id
                        and t.kind = 'arrived'
                    ),
                  'departedAt',
                    (
                      select min(t.occurred_at)
                      from public.trip_events t
                      where t.user_id = vs.user_id
                        and t.load_id = vs.load_id
                        and t.stop_id = vs.id
                        and t.kind = 'departed'
                    )
                )
                order by vs.sequence
              )
              from visible_stops vs
            ),
            '[]'::jsonb
          ),
        'eta',
          coalesce(
            (
              select jsonb_build_object(
                'status', case when a.show_eta then 'available' else 'unavailable' end,
                'stopId',
                  case
                    when a.show_eta
                      and le.stop_id is not null
                      and exists (select 1 from visible_stops vs where vs.id = le.stop_id)
                    then le.stop_id::text
                    else null
                  end,
                'estimatedArrivalAt', case when a.show_eta then le.estimated_arrival_at else null end,
                'source',
                  case
                    when not a.show_eta then null
                    when le.source = 'on_device' then 'on_device_estimate'
                    else le.source
                  end,
                'refreshedAt', case when a.show_eta then le.generated_at else null end
              )
              from latest_eta le
              limit 1
            ),
            jsonb_build_object(
              'status', 'unavailable',
              'stopId', null,
              'estimatedArrivalAt', null,
              'source', null,
              'refreshedAt', null
            )
          ),
        'latestDelay',
          (
            select case
              when a.show_eta and nullif(btrim(le.delay_reason), '') is not null
              then jsonb_build_object(
                'reason', le.delay_reason,
                'reportedAt', le.generated_at
              )
              else null
            end
            from latest_eta le
            limit 1
          ),
        'pod', jsonb_build_object(
          'available', (select available_at is not null from pod_availability),
          'availableAt', (select available_at from pod_availability)
        ),
        'freshness', jsonb_build_object(
          'status',
            case
              when exists (
                select 1
                from latest_eta le
                where a.show_eta
                  and le.generated_at + make_interval(secs => le.stale_after_seconds) <= now()
              ) then 'stale'
              when now() - (select last_updated_at from freshness) > interval '2 hours' then 'offline_no_update'
              else 'current'
            end,
          'lastUpdatedAt', (select last_updated_at from freshness),
          'displayText',
            case
              when exists (
                select 1
                from latest_eta le
                where a.show_eta
                  and le.generated_at + make_interval(secs => le.stale_after_seconds) <= now()
              ) then 'Last update may be stale.'
              when now() - (select last_updated_at from freshness) > interval '2 hours' then 'No recent tracking update.'
              else 'Tracking is current.'
            end
        ),
        'events',
          coalesce(
            (
              select jsonb_agg(
                jsonb_build_object(
                  'id', public_events.id,
                  'type', public_events.type,
                  'stopId', public_events.stop_id,
                  'occurredAt', public_events.occurred_at,
                  'summary', public_events.summary
                )
                order by public_events.occurred_at
              )
              from (
                select
                  t.id::text as id,
                  case
                    when t.kind = 'arrived' then 'arrived'
                    when t.kind = 'departed' then 'departed'
                    when t.kind = 'status_changed' and t.to_status = 'in_transit' then 'loaded'
                    when t.kind = 'status_changed' and t.to_status in ('delivered', 'invoiced', 'paid') then 'delivered'
                    else null
                  end as type,
                  case
                    when t.stop_id is not null
                      and exists (select 1 from visible_stops vs where vs.id = t.stop_id)
                    then t.stop_id::text
                    else null
                  end as stop_id,
                  t.occurred_at,
                  case
                    when t.kind = 'arrived' then 'Arrived.'
                    when t.kind = 'departed' then 'Departed.'
                    when t.kind = 'status_changed' and t.to_status = 'in_transit' then 'Loaded.'
                    when t.kind = 'status_changed' and t.to_status in ('delivered', 'invoiced', 'paid') then 'Delivered.'
                    else null
                  end as summary
                from public.trip_events t
                where t.user_id = a.user_id
                  and t.load_id = a.load_id
                  and (
                    t.stop_id is null
                    or exists (select 1 from visible_stops vs where vs.id = t.stop_id)
                  )
                union all
                select
                  le.id::text,
                  'eta_published',
                  case
                    when le.stop_id is not null
                      and exists (select 1 from visible_stops vs where vs.id = le.stop_id)
                    then le.stop_id::text
                    else null
                  end,
                  le.generated_at,
                  'ETA updated.'
                from latest_eta le
                where a.show_eta
                union all
                select
                  le.id::text || '-delay',
                  'delay_reported',
                  case
                    when le.stop_id is not null
                      and exists (select 1 from visible_stops vs where vs.id = le.stop_id)
                    then le.stop_id::text
                    else null
                  end,
                  le.generated_at,
                  'Delay reported.'
                from latest_eta le
                where a.show_eta
                  and nullif(btrim(le.delay_reason), '') is not null
              ) public_events
              where public_events.type is not null
            ),
            '[]'::jsonb
          )
      )
      from active_share a
    )
  end;
$$;

comment on function public.read_public_tracking_share(text) is
  'Validates a broker tracking token and returns the approved public TrackingResponse JSON, or null for invalid, expired, or revoked access.';

revoke execute on function public.read_public_tracking_share(text) from public, anon, authenticated;
grant execute on function public.read_public_tracking_share(text) to service_role;
