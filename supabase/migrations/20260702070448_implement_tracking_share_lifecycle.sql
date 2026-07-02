-- P0-BE-07: Tracking-share lifecycle contracts.
--
-- BE-03 created the tracking_shares table and BE-04 scoped it to the
-- authenticated owner. This migration adds the server-side token lifecycle:
-- create, preview, shorten expiry, and revoke. The plaintext token is returned
-- only once from create_tracking_share; durable rows keep only the SHA-256 hash.

create extension if not exists pgcrypto with schema extensions;

alter table public.tracking_shares
  alter column expires_at drop not null,
  add column stop_scope text not null default 'all',
  add constraint tracking_shares_stop_scope_allowed
    check (stop_scope in ('pickup', 'delivery', 'all'));

comment on column public.tracking_shares.token_hash is
  'SHA-256 hash of the broker-facing share token. The plaintext token is never stored.';
comment on column public.tracking_shares.expires_at is
  'Optional shortened expiry. Null means the default effective expiry is 72 hours after load delivery.';
comment on column public.tracking_shares.stop_scope is
  'Visible stop scope for this share: pickup, delivery, or all stops.';

create index tracking_shares_active_load_idx
on public.tracking_shares (user_id, load_id, revoked_at);

create or replace function app_private.generate_tracking_share_token()
returns text
language sql
volatile
security invoker
set search_path = ''
as $$
  select translate(
    rtrim(encode(extensions.gen_random_bytes(32), 'base64'), '='),
    '+/',
    '-_'
  );
$$;

comment on function app_private.generate_tracking_share_token() is
  'Generates a URL-safe 256-bit tracking-share token.';

revoke execute on function app_private.generate_tracking_share_token() from public, anon, authenticated;

create or replace function app_private.hash_tracking_share_token(p_token text)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select encode(extensions.digest(p_token, 'sha256'), 'hex');
$$;

comment on function app_private.hash_tracking_share_token(text) is
  'Hashes a tracking-share token for durable storage and lookup.';

revoke execute on function app_private.hash_tracking_share_token(text) from public, anon, authenticated;

create or replace function app_private.tracking_share_default_expires_at(
  p_delivered_at timestamp with time zone
)
returns timestamp with time zone
language sql
immutable
security invoker
set search_path = ''
as $$
  select case
    when p_delivered_at is null then null
    else p_delivered_at + interval '72 hours'
  end;
$$;

revoke execute on function app_private.tracking_share_default_expires_at(timestamp with time zone) from public, anon, authenticated;

create or replace function app_private.tracking_share_effective_expires_at(
  p_expires_at timestamp with time zone,
  p_delivered_at timestamp with time zone
)
returns timestamp with time zone
language sql
immutable
security invoker
set search_path = ''
as $$
  select coalesce(
    p_expires_at,
    app_private.tracking_share_default_expires_at(p_delivered_at)
  );
$$;

revoke execute on function app_private.tracking_share_effective_expires_at(timestamp with time zone, timestamp with time zone) from public, anon, authenticated;

create or replace function app_private.tracking_share_state(
  p_expires_at timestamp with time zone,
  p_revoked_at timestamp with time zone,
  p_delivered_at timestamp with time zone
)
returns text
language sql
stable
security invoker
set search_path = ''
as $$
  select case
    when p_revoked_at is not null then 'revoked'
    when app_private.tracking_share_effective_expires_at(p_expires_at, p_delivered_at) is not null
      and app_private.tracking_share_effective_expires_at(p_expires_at, p_delivered_at) <= now()
      then 'expired'
    else 'active'
  end;
$$;

revoke execute on function app_private.tracking_share_state(timestamp with time zone, timestamp with time zone, timestamp with time zone) from public, anon, authenticated;

create or replace function app_private.build_tracking_share_preview(
  p_share public.tracking_shares,
  p_load public.loads
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'share_id', p_share.id,
    'load_id', p_share.load_id,
    'state', app_private.tracking_share_state(p_share.expires_at, p_share.revoked_at, p_load.delivered_at),
    'stop_scope', p_share.stop_scope,
    'expires_at', p_share.expires_at,
    'effective_expires_at', app_private.tracking_share_effective_expires_at(p_share.expires_at, p_load.delivered_at),
    'revoked_at', p_share.revoked_at,
    'load', jsonb_build_object(
      'reference_number', p_load.reference_number,
      'status', p_load.status,
      'delivered_at', p_load.delivered_at
    ),
    'visibility', jsonb_build_object(
      'show_carrier_name', p_share.show_carrier_name,
      'show_reference_number', p_share.show_reference_number,
      'show_stops', p_share.show_stops,
      'show_eta', p_share.show_eta,
      'show_pod_availability', p_share.show_pod_availability
    ),
    'visible_stops',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', s.id,
              'kind', s.kind,
              'sequence', s.sequence,
              'facility_name', s.facility_name,
              'appointment_starts_at', s.appointment_starts_at,
              'appointment_ends_at', s.appointment_ends_at,
              'appointment_timezone', s.appointment_timezone
            )
            order by s.sequence
          )
          from public.stops s
          where p_share.show_stops
            and s.user_id = p_share.user_id
            and s.load_id = p_share.load_id
            and (
              p_share.stop_scope = 'all'
              or s.kind = p_share.stop_scope
            )
        ),
        '[]'::jsonb
      )
  );
$$;

comment on function app_private.build_tracking_share_preview(public.tracking_shares, public.loads) is
  'Builds the owner-facing preview payload without returning token material or financial fields.';

revoke execute on function app_private.build_tracking_share_preview(public.tracking_shares, public.loads) from public, anon, authenticated;

create or replace function public.create_tracking_share(
  p_share_id uuid,
  p_load_id uuid,
  p_stop_scope text default 'all',
  p_visibility jsonb default '{}'::jsonb,
  p_expires_at timestamp with time zone default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_load public.loads%rowtype;
  v_share public.tracking_shares%rowtype;
  v_share_id uuid := coalesce(p_share_id, extensions.gen_random_uuid());
  v_stop_scope text := coalesce(nullif(btrim(p_stop_scope), ''), 'all');
  v_token text;
  v_token_hash text;
  v_default_expires_at timestamp with time zone;
begin
  if v_user_id is null then
    raise exception 'create_tracking_share requires an authenticated user'
      using errcode = '42501';
  end if;

  if p_load_id is null then
    raise exception 'load_id is required'
      using errcode = '23502';
  end if;

  if v_stop_scope not in ('pickup', 'delivery', 'all') then
    raise exception 'stop_scope must be pickup, delivery, or all'
      using errcode = '22023';
  end if;

  select *
  into v_load
  from public.loads
  where id = p_load_id
    and user_id = v_user_id;

  if not found then
    raise exception 'load not found for authenticated user'
      using errcode = '42501';
  end if;

  v_default_expires_at := app_private.tracking_share_default_expires_at(v_load.delivered_at);

  if v_default_expires_at is not null and v_default_expires_at <= now() then
    raise exception 'default tracking-share window has already expired'
      using errcode = '22023';
  end if;

  if p_expires_at is not null and p_expires_at <= now() then
    raise exception 'expires_at must be in the future'
      using errcode = '22023';
  end if;

  if p_expires_at is not null
     and v_default_expires_at is not null
     and p_expires_at > v_default_expires_at then
    raise exception 'expires_at cannot extend beyond the default delivery window'
      using errcode = '22023';
  end if;

  v_token := app_private.generate_tracking_share_token();
  v_token_hash := app_private.hash_tracking_share_token(v_token);

  insert into public.tracking_shares (
    id,
    user_id,
    load_id,
    token_hash,
    expires_at,
    stop_scope,
    show_carrier_name,
    show_reference_number,
    show_stops,
    show_eta,
    show_pod_availability
  )
  values (
    v_share_id,
    v_user_id,
    p_load_id,
    v_token_hash,
    coalesce(p_expires_at, v_default_expires_at),
    v_stop_scope,
    coalesce((p_visibility ->> 'show_carrier_name')::boolean, true),
    coalesce((p_visibility ->> 'show_reference_number')::boolean, true),
    coalesce((p_visibility ->> 'show_stops')::boolean, true),
    coalesce((p_visibility ->> 'show_eta')::boolean, true),
    coalesce((p_visibility ->> 'show_pod_availability')::boolean, true)
  )
  returning *
  into v_share;

  return app_private.build_tracking_share_preview(v_share, v_load)
    || jsonb_build_object(
      'token', v_token,
      'token_bits', 256
    );
end;
$$;

comment on function public.create_tracking_share(uuid, uuid, text, jsonb, timestamp with time zone) is
  'Creates a tracking share for an owned load and returns the plaintext token once.';

revoke execute on function public.create_tracking_share(uuid, uuid, text, jsonb, timestamp with time zone) from public, anon;
grant execute on function public.create_tracking_share(uuid, uuid, text, jsonb, timestamp with time zone) to authenticated, service_role;

create or replace function public.preview_tracking_share(p_share_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_share public.tracking_shares%rowtype;
  v_load public.loads%rowtype;
begin
  if v_user_id is null then
    raise exception 'preview_tracking_share requires an authenticated user'
      using errcode = '42501';
  end if;

  select *
  into v_share
  from public.tracking_shares
  where id = p_share_id
    and user_id = v_user_id;

  if not found then
    raise exception 'tracking share not found for authenticated user'
      using errcode = '42501';
  end if;

  select *
  into v_load
  from public.loads
  where id = v_share.load_id
    and user_id = v_user_id;

  if not found then
    raise exception 'tracking share load not found for authenticated user'
      using errcode = '42501';
  end if;

  return app_private.build_tracking_share_preview(v_share, v_load);
end;
$$;

comment on function public.preview_tracking_share(uuid) is
  'Returns the owner-facing tracking-share preview without token material.';

revoke execute on function public.preview_tracking_share(uuid) from public, anon;
grant execute on function public.preview_tracking_share(uuid) to authenticated, service_role;

create or replace function public.shorten_tracking_share_expiry(
  p_share_id uuid,
  p_expires_at timestamp with time zone
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_share public.tracking_shares%rowtype;
  v_load public.loads%rowtype;
  v_current_effective_expires_at timestamp with time zone;
begin
  if v_user_id is null then
    raise exception 'shorten_tracking_share_expiry requires an authenticated user'
      using errcode = '42501';
  end if;

  if p_expires_at is null or p_expires_at <= now() then
    raise exception 'expires_at must be in the future'
      using errcode = '22023';
  end if;

  select *
  into v_share
  from public.tracking_shares
  where id = p_share_id
    and user_id = v_user_id
  for update;

  if not found then
    raise exception 'tracking share not found for authenticated user'
      using errcode = '42501';
  end if;

  select *
  into v_load
  from public.loads
  where id = v_share.load_id
    and user_id = v_user_id;

  if not found then
    raise exception 'tracking share load not found for authenticated user'
      using errcode = '42501';
  end if;

  v_current_effective_expires_at := app_private.tracking_share_effective_expires_at(
    v_share.expires_at,
    v_load.delivered_at
  );

  if v_current_effective_expires_at is not null
     and p_expires_at >= v_current_effective_expires_at then
    raise exception 'expires_at can only shorten the current effective expiry'
      using errcode = '22023';
  end if;

  update public.tracking_shares
  set expires_at = p_expires_at
  where id = v_share.id
    and user_id = v_user_id
  returning *
  into v_share;

  return app_private.build_tracking_share_preview(v_share, v_load);
end;
$$;

comment on function public.shorten_tracking_share_expiry(uuid, timestamp with time zone) is
  'Shortens an owned tracking share expiry without allowing extensions.';

revoke execute on function public.shorten_tracking_share_expiry(uuid, timestamp with time zone) from public, anon;
grant execute on function public.shorten_tracking_share_expiry(uuid, timestamp with time zone) to authenticated, service_role;

create or replace function public.revoke_tracking_share(p_share_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_share public.tracking_shares%rowtype;
  v_load public.loads%rowtype;
begin
  if v_user_id is null then
    raise exception 'revoke_tracking_share requires an authenticated user'
      using errcode = '42501';
  end if;

  select *
  into v_share
  from public.tracking_shares
  where id = p_share_id
    and user_id = v_user_id
  for update;

  if not found then
    raise exception 'tracking share not found for authenticated user'
      using errcode = '42501';
  end if;

  select *
  into v_load
  from public.loads
  where id = v_share.load_id
    and user_id = v_user_id;

  if not found then
    raise exception 'tracking share load not found for authenticated user'
      using errcode = '42501';
  end if;

  update public.tracking_shares
  set revoked_at = coalesce(revoked_at, now())
  where id = v_share.id
    and user_id = v_user_id
  returning *
  into v_share;

  return app_private.build_tracking_share_preview(v_share, v_load);
end;
$$;

comment on function public.revoke_tracking_share(uuid) is
  'Immediately revokes an owned tracking share.';

revoke execute on function public.revoke_tracking_share(uuid) from public, anon;
grant execute on function public.revoke_tracking_share(uuid) to authenticated, service_role;
