-- P0-BE-03: Relational load-to-cash schema.
--
-- Tables in this migration use client-provided UUID primary keys so the
-- local-first app can create records before sync. Every owned row carries
-- user_id, created_at, and updated_at. Composite foreign keys keep child rows
-- attached to parents owned by the same account even before BE-04 RLS policies.

create table public.vehicles (
  id uuid primary key,
  user_id uuid not null references public.business_profiles(user_id) on delete cascade,
  equipment_name text not null,
  fuel_economy_mpg numeric(8, 2) not null,
  fuel_price_per_gallon numeric(10, 2) not null,
  maintenance_reserve_per_mile numeric(10, 2) not null,
  monthly_fixed_costs numeric(12, 2) not null,
  estimated_working_miles numeric(10, 2) not null,
  dispatch_fee_percent numeric(7, 4) not null default 0,
  factoring_fee_percent numeric(7, 4) not null default 0,
  profit_target_percent numeric(7, 4) not null default 0,
  is_default boolean not null default false,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint vehicles_user_id_id_unique unique (user_id, id),
  constraint vehicles_equipment_name_required
    check (char_length(btrim(equipment_name)) > 0),
  constraint vehicles_equipment_name_length
    check (char_length(btrim(equipment_name)) <= 160),
  constraint vehicles_fuel_economy_positive
    check (fuel_economy_mpg > 0),
  constraint vehicles_fuel_price_non_negative
    check (fuel_price_per_gallon >= 0),
  constraint vehicles_maintenance_reserve_non_negative
    check (maintenance_reserve_per_mile >= 0),
  constraint vehicles_monthly_fixed_costs_non_negative
    check (monthly_fixed_costs >= 0),
  constraint vehicles_working_miles_positive
    check (estimated_working_miles > 0),
  constraint vehicles_dispatch_fee_percent_range
    check (dispatch_fee_percent >= 0 and dispatch_fee_percent <= 100),
  constraint vehicles_factoring_fee_percent_range
    check (factoring_fee_percent >= 0 and factoring_fee_percent <= 100),
  constraint vehicles_profit_target_percent_range
    check (profit_target_percent >= 0 and profit_target_percent <= 100)
);

comment on table public.vehicles is
  'User-owned equipment and default operating-cost assumptions for load profitability.';
comment on column public.vehicles.id is
  'Client-generated UUID so vehicle defaults can be created offline before sync.';

create table public.customers (
  id uuid primary key,
  user_id uuid not null references public.business_profiles(user_id) on delete cascade,
  name text not null,
  kind text not null default 'broker',
  contact_name text,
  phone text,
  email text,
  mailing_address text,
  notes text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint customers_user_id_id_unique unique (user_id, id),
  constraint customers_name_required
    check (char_length(btrim(name)) > 0),
  constraint customers_name_length
    check (char_length(btrim(name)) <= 160),
  constraint customers_kind_allowed
    check (kind in ('broker', 'shipper', 'receiver', 'direct_customer', 'other')),
  constraint customers_contact_name_length
    check (contact_name is null or char_length(btrim(contact_name)) <= 160),
  constraint customers_phone_length
    check (phone is null or char_length(btrim(phone)) <= 50),
  constraint customers_email_length
    check (email is null or char_length(btrim(email)) <= 320),
  constraint customers_email_format
    check (email is null or email ~* '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$'),
  constraint customers_mailing_address_length
    check (mailing_address is null or char_length(btrim(mailing_address)) <= 1000),
  constraint customers_notes_length
    check (notes is null or char_length(btrim(notes)) <= 2000)
);

comment on table public.customers is
  'User-owned brokers, shippers, receivers, direct customers, and other load parties.';

create table public.loads (
  id uuid primary key,
  user_id uuid not null references public.business_profiles(user_id) on delete cascade,
  vehicle_id uuid,
  customer_id uuid not null,
  reference_number text not null,
  status text not null default 'evaluating',
  line_haul_rate numeric(12, 2) not null,
  fuel_surcharge numeric(12, 2) not null default 0,
  accessorial_revenue numeric(12, 2) not null default 0,
  loaded_miles numeric(10, 2) not null,
  deadhead_miles numeric(10, 2) not null default 0,
  estimated_tolls numeric(12, 2) not null default 0,
  fuel_economy_mpg numeric(8, 2),
  fuel_price_per_gallon numeric(10, 2),
  maintenance_reserve_per_mile numeric(10, 2),
  monthly_fixed_costs numeric(12, 2),
  working_miles_per_month numeric(10, 2),
  gross_revenue numeric(12, 2),
  fuel_cost numeric(12, 2),
  maintenance_cost numeric(12, 2),
  fixed_cost_allocation numeric(12, 2),
  fee_cost numeric(12, 2),
  total_operating_cost numeric(12, 2),
  estimated_profit numeric(12, 2),
  profit_margin numeric(7, 4),
  revenue_per_loaded_mile numeric(12, 2),
  revenue_per_total_mile numeric(12, 2),
  accepted_at timestamp with time zone,
  delivered_at timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint loads_user_id_id_unique unique (user_id, id),
  constraint loads_vehicle_same_user_fkey
    foreign key (user_id, vehicle_id) references public.vehicles(user_id, id) on delete set null (vehicle_id),
  constraint loads_customer_same_user_fkey
    foreign key (user_id, customer_id) references public.customers(user_id, id) on delete cascade,
  constraint loads_reference_required
    check (char_length(btrim(reference_number)) > 0),
  constraint loads_reference_length
    check (char_length(btrim(reference_number)) <= 80),
  constraint loads_status_allowed
    check (
      status in (
        'evaluating',
        'accepted',
        'en_route_to_pickup',
        'at_pickup',
        'in_transit',
        'at_delivery',
        'delivered',
        'invoiced',
        'paid',
        'cancelled',
        'disputed'
      )
    ),
  constraint loads_line_haul_positive
    check (line_haul_rate > 0),
  constraint loads_revenue_non_negative
    check (fuel_surcharge >= 0 and accessorial_revenue >= 0),
  constraint loads_mileage_valid
    check (loaded_miles > 0 and deadhead_miles >= 0),
  constraint loads_estimated_tolls_non_negative
    check (estimated_tolls >= 0),
  constraint loads_cost_overrides_valid
    check (
      (fuel_economy_mpg is null or fuel_economy_mpg > 0)
      and (fuel_price_per_gallon is null or fuel_price_per_gallon >= 0)
      and (maintenance_reserve_per_mile is null or maintenance_reserve_per_mile >= 0)
      and (monthly_fixed_costs is null or monthly_fixed_costs >= 0)
      and (working_miles_per_month is null or working_miles_per_month > 0)
    ),
  constraint loads_calculated_money_non_negative
    check (
      (gross_revenue is null or gross_revenue >= 0)
      and (fuel_cost is null or fuel_cost >= 0)
      and (maintenance_cost is null or maintenance_cost >= 0)
      and (fixed_cost_allocation is null or fixed_cost_allocation >= 0)
      and (fee_cost is null or fee_cost >= 0)
      and (total_operating_cost is null or total_operating_cost >= 0)
      and (revenue_per_loaded_mile is null or revenue_per_loaded_mile >= 0)
      and (revenue_per_total_mile is null or revenue_per_total_mile >= 0)
    ),
  constraint loads_profit_margin_range
    check (profit_margin is null or profit_margin <= 1),
  constraint loads_delivered_after_accepted
    check (accepted_at is null or delivered_at is null or delivered_at >= accepted_at)
);

comment on table public.loads is
  'User-owned commercial terms, miles, state, and calculated load summary.';
comment on column public.loads.id is
  'Client-generated UUID for offline load creation and idempotent sync.';

create table public.stops (
  id uuid primary key,
  user_id uuid not null references public.business_profiles(user_id) on delete cascade,
  load_id uuid not null,
  kind text not null,
  sequence integer not null,
  facility_name text not null,
  address text,
  appointment_starts_at timestamp with time zone,
  appointment_ends_at timestamp with time zone,
  appointment_timezone text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint stops_user_id_id_unique unique (user_id, id),
  constraint stops_load_sequence_unique unique (load_id, sequence),
  constraint stops_load_same_user_fkey
    foreign key (user_id, load_id) references public.loads(user_id, id) on delete cascade,
  constraint stops_kind_allowed
    check (kind in ('pickup', 'delivery', 'extra')),
  constraint stops_sequence_positive
    check (sequence > 0),
  constraint stops_facility_name_required
    check (char_length(btrim(facility_name)) > 0),
  constraint stops_facility_name_length
    check (char_length(btrim(facility_name)) <= 160),
  constraint stops_address_length
    check (address is null or char_length(btrim(address)) <= 1000),
  constraint stops_appointment_complete
    check (
      (appointment_starts_at is null and appointment_ends_at is null and appointment_timezone is null)
      or (
        appointment_starts_at is not null
        and appointment_ends_at is not null
        and appointment_timezone is not null
        and char_length(btrim(appointment_timezone)) > 0
        and appointment_ends_at >= appointment_starts_at
      )
    )
);

comment on table public.stops is
  'Pickup, delivery, and extra-stop appointments for a load.';

create table public.trip_events (
  id uuid primary key,
  user_id uuid not null references public.business_profiles(user_id) on delete cascade,
  load_id uuid not null,
  stop_id uuid,
  original_event_id uuid,
  kind text not null,
  status text not null,
  from_status text,
  to_status text,
  occurred_at timestamp with time zone not null,
  timezone_identifier text not null,
  location_source text not null default 'unavailable',
  latitude numeric(9, 6),
  longitude numeric(9, 6),
  horizontal_accuracy_meters numeric(10, 2),
  note text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint trip_events_user_id_id_unique unique (user_id, id),
  constraint trip_events_load_same_user_fkey
    foreign key (user_id, load_id) references public.loads(user_id, id) on delete cascade,
  constraint trip_events_stop_same_user_fkey
    foreign key (user_id, stop_id) references public.stops(user_id, id) on delete cascade,
  constraint trip_events_original_event_same_user_fkey
    foreign key (user_id, original_event_id) references public.trip_events(user_id, id) on delete cascade,
  constraint trip_events_kind_allowed
    check (kind in ('status_changed', 'arrived', 'departed', 'corrected')),
  constraint trip_events_status_allowed
    check (
      status in (
        'evaluating',
        'accepted',
        'en_route_to_pickup',
        'at_pickup',
        'in_transit',
        'at_delivery',
        'delivered',
        'invoiced',
        'paid',
        'cancelled',
        'disputed'
      )
    ),
  constraint trip_events_from_status_allowed
    check (
      from_status is null
      or from_status in (
        'evaluating',
        'accepted',
        'en_route_to_pickup',
        'at_pickup',
        'in_transit',
        'at_delivery',
        'delivered',
        'invoiced',
        'paid',
        'cancelled',
        'disputed'
      )
    ),
  constraint trip_events_to_status_allowed
    check (
      to_status is null
      or to_status in (
        'evaluating',
        'accepted',
        'en_route_to_pickup',
        'at_pickup',
        'in_transit',
        'at_delivery',
        'delivered',
        'invoiced',
        'paid',
        'cancelled',
        'disputed'
      )
    ),
  constraint trip_events_status_change_shape
    check (
      (kind = 'status_changed' and from_status is not null and to_status is not null and original_event_id is null)
      or (kind in ('arrived', 'departed') and stop_id is not null and from_status is null and to_status is null and original_event_id is null)
      or (kind = 'corrected' and original_event_id is not null and from_status is null and to_status is null)
    ),
  constraint trip_events_timezone_required
    check (char_length(btrim(timezone_identifier)) > 0),
  constraint trip_events_location_source_allowed
    check (location_source in ('device_verified', 'poor_accuracy', 'unavailable', 'permission_denied', 'manual')),
  constraint trip_events_location_shape
    check (
      (
        location_source in ('device_verified', 'poor_accuracy')
        and latitude is not null
        and longitude is not null
        and horizontal_accuracy_meters is not null
      )
      or (
        location_source in ('unavailable', 'permission_denied', 'manual')
        and latitude is null
        and longitude is null
        and horizontal_accuracy_meters is null
      )
    ),
  constraint trip_events_latitude_range
    check (latitude is null or (latitude >= -90 and latitude <= 90)),
  constraint trip_events_longitude_range
    check (longitude is null or (longitude >= -180 and longitude <= 180)),
  constraint trip_events_accuracy_non_negative
    check (horizontal_accuracy_meters is null or horizontal_accuracy_meters >= 0),
  constraint trip_events_note_length
    check (note is null or char_length(btrim(note)) <= 2000),
  constraint trip_events_correction_note_required
    check (kind <> 'corrected' or char_length(btrim(coalesce(note, ''))) > 0)
);

comment on table public.trip_events is
  'Immutable arrival, departure, status, GPS, and correction events appended to a load.';

create table public.charges (
  id uuid primary key,
  user_id uuid not null references public.business_profiles(user_id) on delete cascade,
  load_id uuid not null,
  source_trip_event_id uuid,
  kind text not null,
  description text not null,
  amount numeric(12, 2) not null,
  quantity numeric(12, 2),
  rate numeric(12, 2),
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint charges_user_id_id_unique unique (user_id, id),
  constraint charges_load_same_user_fkey
    foreign key (user_id, load_id) references public.loads(user_id, id) on delete cascade,
  constraint charges_trip_event_same_user_fkey
    foreign key (user_id, source_trip_event_id) references public.trip_events(user_id, id) on delete set null (source_trip_event_id),
  constraint charges_kind_allowed
    check (kind in ('line_haul', 'fuel_surcharge', 'detention', 'accessorial', 'adjustment')),
  constraint charges_description_required
    check (char_length(btrim(description)) > 0),
  constraint charges_description_length
    check (char_length(btrim(description)) <= 500),
  constraint charges_amount_non_negative
    check (amount >= 0),
  constraint charges_quantity_positive
    check (quantity is null or quantity > 0),
  constraint charges_rate_non_negative
    check (rate is null or rate >= 0)
);

comment on table public.charges is
  'Line haul, fuel surcharge, detention, and other accessorial charge records.';

create table public.expenses (
  id uuid primary key,
  user_id uuid not null references public.business_profiles(user_id) on delete cascade,
  load_id uuid not null,
  kind text not null,
  description text not null,
  amount numeric(12, 2) not null,
  incurred_at timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint expenses_user_id_id_unique unique (user_id, id),
  constraint expenses_load_same_user_fkey
    foreign key (user_id, load_id) references public.loads(user_id, id) on delete cascade,
  constraint expenses_kind_allowed
    check (kind in ('fuel', 'toll', 'lumper', 'maintenance', 'parking', 'other')),
  constraint expenses_description_required
    check (char_length(btrim(description)) > 0),
  constraint expenses_description_length
    check (char_length(btrim(description)) <= 500),
  constraint expenses_amount_non_negative
    check (amount >= 0)
);

comment on table public.expenses is
  'Fuel, toll, lumper, and load-specific operating costs.';

create table public.documents (
  id uuid primary key,
  user_id uuid not null references public.business_profiles(user_id) on delete cascade,
  load_id uuid,
  kind text not null,
  file_name text not null,
  content_type text not null,
  byte_count bigint not null,
  sha256_hex text,
  object_key text,
  sync_state text not null default 'local_only',
  uploaded_at timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint documents_user_id_id_unique unique (user_id, id),
  constraint documents_load_same_user_fkey
    foreign key (user_id, load_id) references public.loads(user_id, id) on delete cascade,
  constraint documents_kind_allowed
    check (
      kind in (
        'rate_confirmation',
        'bill_of_lading',
        'proof_of_delivery',
        'receipt',
        'lumper_receipt',
        'invoice',
        'other_evidence'
      )
    ),
  constraint documents_file_name_required
    check (char_length(btrim(file_name)) > 0),
  constraint documents_file_name_length
    check (char_length(btrim(file_name)) <= 255),
  constraint documents_content_type_required
    check (char_length(btrim(content_type)) > 0),
  constraint documents_content_type_length
    check (char_length(btrim(content_type)) <= 255),
  constraint documents_byte_count_non_negative
    check (byte_count >= 0),
  constraint documents_sha256_hex_format
    check (sha256_hex is null or sha256_hex ~ '^[0-9a-f]{64}$'),
  constraint documents_object_key_length
    check (object_key is null or (char_length(btrim(object_key)) > 0 and char_length(btrim(object_key)) <= 1024)),
  constraint documents_sync_state_allowed
    check (sync_state in ('local_only', 'queued', 'uploading', 'synced', 'failed', 'inspect')),
  constraint documents_synced_requires_object_key
    check (sync_state <> 'synced' or object_key is not null)
);

comment on table public.documents is
  'Private document metadata; storage buckets and signed URLs are implemented by the storage slice.';

create table public.invoices (
  id uuid primary key,
  user_id uuid not null references public.business_profiles(user_id) on delete cascade,
  load_id uuid not null,
  invoice_number text not null,
  status text not null default 'draft',
  issued_at timestamp with time zone,
  due_at timestamp with time zone,
  current_revision_number integer not null default 1,
  total_amount numeric(12, 2) not null default 0,
  total_paid numeric(12, 2) not null default 0,
  remaining_balance numeric(12, 2) not null default 0,
  unapplied_credit numeric(12, 2) not null default 0,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint invoices_user_id_id_unique unique (user_id, id),
  constraint invoices_user_number_unique unique (user_id, invoice_number),
  constraint invoices_load_same_user_fkey
    foreign key (user_id, load_id) references public.loads(user_id, id) on delete cascade,
  constraint invoices_number_required
    check (char_length(btrim(invoice_number)) > 0),
  constraint invoices_number_length
    check (char_length(btrim(invoice_number)) <= 80),
  constraint invoices_status_allowed
    check (status in ('draft', 'sent', 'partial', 'paid', 'void', 'disputed')),
  constraint invoices_revision_positive
    check (current_revision_number > 0),
  constraint invoices_money_non_negative
    check (total_amount >= 0 and total_paid >= 0 and remaining_balance >= 0 and unapplied_credit >= 0),
  constraint invoices_due_after_issued
    check (issued_at is null or due_at is null or due_at >= issued_at)
);

comment on table public.invoices is
  'Invoice header and current payment state for a load.';

create table public.invoice_revisions (
  id uuid primary key,
  user_id uuid not null references public.business_profiles(user_id) on delete cascade,
  invoice_id uuid not null,
  revision_number integer not null,
  total_amount numeric(12, 2) not null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  notes text,

  constraint invoice_revisions_user_id_id_unique unique (user_id, id),
  constraint invoice_revisions_invoice_revision_unique unique (invoice_id, revision_number),
  constraint invoice_revisions_invoice_same_user_fkey
    foreign key (user_id, invoice_id) references public.invoices(user_id, id) on delete cascade,
  constraint invoice_revisions_revision_positive
    check (revision_number > 0),
  constraint invoice_revisions_total_non_negative
    check (total_amount >= 0),
  constraint invoice_revisions_notes_length
    check (notes is null or char_length(btrim(notes)) <= 2000)
);

comment on table public.invoice_revisions is
  'Immutable invoice revision snapshots. New financial edits append a revision.';

create table public.invoice_items (
  id uuid primary key,
  user_id uuid not null references public.business_profiles(user_id) on delete cascade,
  invoice_revision_id uuid not null,
  source_charge_id uuid,
  source_document_id uuid,
  sequence integer not null,
  kind text not null,
  description text not null,
  amount numeric(12, 2) not null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint invoice_items_user_id_id_unique unique (user_id, id),
  constraint invoice_items_revision_sequence_unique unique (invoice_revision_id, sequence),
  constraint invoice_items_revision_same_user_fkey
    foreign key (user_id, invoice_revision_id) references public.invoice_revisions(user_id, id) on delete cascade,
  constraint invoice_items_charge_same_user_fkey
    foreign key (user_id, source_charge_id) references public.charges(user_id, id) on delete set null (source_charge_id),
  constraint invoice_items_document_same_user_fkey
    foreign key (user_id, source_document_id) references public.documents(user_id, id) on delete set null (source_document_id),
  constraint invoice_items_sequence_positive
    check (sequence > 0),
  constraint invoice_items_kind_allowed
    check (kind in ('line_haul', 'fuel_surcharge', 'detention', 'accessorial', 'adjustment')),
  constraint invoice_items_description_required
    check (char_length(btrim(description)) > 0),
  constraint invoice_items_description_length
    check (char_length(btrim(description)) <= 500),
  constraint invoice_items_amount_non_negative
    check (amount >= 0)
);

comment on table public.invoice_items is
  'Billed line items for a specific invoice revision, optionally linked to charge or document evidence.';

create table public.payments (
  id uuid primary key,
  user_id uuid not null references public.business_profiles(user_id) on delete cascade,
  invoice_id uuid not null,
  amount numeric(12, 2) not null,
  received_at timestamp with time zone not null,
  method text,
  note text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint payments_user_id_id_unique unique (user_id, id),
  constraint payments_invoice_same_user_fkey
    foreign key (user_id, invoice_id) references public.invoices(user_id, id) on delete cascade,
  constraint payments_amount_positive
    check (amount > 0),
  constraint payments_method_length
    check (method is null or char_length(btrim(method)) <= 80),
  constraint payments_note_length
    check (note is null or char_length(btrim(note)) <= 1000)
);

comment on table public.payments is
  'Full or partial payment records for invoice reconciliation.';

create table public.tracking_shares (
  id uuid primary key,
  user_id uuid not null references public.business_profiles(user_id) on delete cascade,
  load_id uuid not null,
  token_hash text not null,
  expires_at timestamp with time zone not null,
  revoked_at timestamp with time zone,
  show_carrier_name boolean not null default true,
  show_reference_number boolean not null default true,
  show_stops boolean not null default true,
  show_eta boolean not null default true,
  show_pod_availability boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint tracking_shares_user_id_id_unique unique (user_id, id),
  constraint tracking_shares_token_hash_unique unique (token_hash),
  constraint tracking_shares_load_same_user_fkey
    foreign key (user_id, load_id) references public.loads(user_id, id) on delete cascade,
  constraint tracking_shares_token_hash_required
    check (char_length(btrim(token_hash)) >= 43),
  constraint tracking_shares_expiry_after_creation
    check (expires_at > created_at),
  constraint tracking_shares_revoked_after_creation
    check (revoked_at is null or revoked_at >= created_at)
);

comment on table public.tracking_shares is
  'Hashed per-load link tokens, visibility settings, expiry, and revocation state.';

create table public.eta_updates (
  id uuid primary key,
  user_id uuid not null references public.business_profiles(user_id) on delete cascade,
  load_id uuid not null,
  stop_id uuid,
  tracking_share_id uuid,
  estimated_arrival_at timestamp with time zone not null,
  generated_at timestamp with time zone not null,
  source text not null,
  stale_after_seconds integer not null default 900,
  delay_reason text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint eta_updates_user_id_id_unique unique (user_id, id),
  constraint eta_updates_load_same_user_fkey
    foreign key (user_id, load_id) references public.loads(user_id, id) on delete cascade,
  constraint eta_updates_stop_same_user_fkey
    foreign key (user_id, stop_id) references public.stops(user_id, id) on delete set null (stop_id),
  constraint eta_updates_share_same_user_fkey
    foreign key (user_id, tracking_share_id) references public.tracking_shares(user_id, id) on delete set null (tracking_share_id),
  constraint eta_updates_source_allowed
    check (source in ('manual', 'on_device')),
  constraint eta_updates_estimate_not_past_generated
    check (estimated_arrival_at >= generated_at),
  constraint eta_updates_stale_after_positive
    check (stale_after_seconds > 0),
  constraint eta_updates_delay_reason_length
    check (delay_reason is null or char_length(btrim(delay_reason)) <= 500)
);

comment on table public.eta_updates is
  'Published ETA, source, delay reason, and freshness timestamp for load visibility.';

create trigger set_vehicles_updated_at
before update on public.vehicles
for each row
execute function app_private.set_updated_at();

create trigger set_customers_updated_at
before update on public.customers
for each row
execute function app_private.set_updated_at();

create trigger set_loads_updated_at
before update on public.loads
for each row
execute function app_private.set_updated_at();

create trigger set_stops_updated_at
before update on public.stops
for each row
execute function app_private.set_updated_at();

create trigger set_trip_events_updated_at
before update on public.trip_events
for each row
execute function app_private.set_updated_at();

create trigger set_charges_updated_at
before update on public.charges
for each row
execute function app_private.set_updated_at();

create trigger set_expenses_updated_at
before update on public.expenses
for each row
execute function app_private.set_updated_at();

create trigger set_documents_updated_at
before update on public.documents
for each row
execute function app_private.set_updated_at();

create trigger set_invoices_updated_at
before update on public.invoices
for each row
execute function app_private.set_updated_at();

create trigger set_invoice_revisions_updated_at
before update on public.invoice_revisions
for each row
execute function app_private.set_updated_at();

create trigger set_invoice_items_updated_at
before update on public.invoice_items
for each row
execute function app_private.set_updated_at();

create trigger set_payments_updated_at
before update on public.payments
for each row
execute function app_private.set_updated_at();

create trigger set_tracking_shares_updated_at
before update on public.tracking_shares
for each row
execute function app_private.set_updated_at();

create trigger set_eta_updates_updated_at
before update on public.eta_updates
for each row
execute function app_private.set_updated_at();

create unique index vehicles_default_per_user_idx
on public.vehicles (user_id)
where is_default;

create index vehicles_user_id_idx on public.vehicles (user_id);
create index customers_user_id_idx on public.customers (user_id);
create index loads_user_id_idx on public.loads (user_id);
create index loads_vehicle_id_idx on public.loads (vehicle_id);
create index loads_customer_id_idx on public.loads (customer_id);
create index loads_status_idx on public.loads (status);
create index stops_user_id_idx on public.stops (user_id);
create index stops_load_id_idx on public.stops (load_id);
create index trip_events_user_id_idx on public.trip_events (user_id);
create index trip_events_load_id_occurred_at_idx on public.trip_events (load_id, occurred_at);
create index trip_events_stop_id_idx on public.trip_events (stop_id);
create index trip_events_original_event_id_idx on public.trip_events (original_event_id);
create index charges_user_id_idx on public.charges (user_id);
create index charges_load_id_idx on public.charges (load_id);
create index charges_source_trip_event_id_idx on public.charges (source_trip_event_id);
create index expenses_user_id_idx on public.expenses (user_id);
create index expenses_load_id_idx on public.expenses (load_id);
create index documents_user_id_idx on public.documents (user_id);
create index documents_load_id_idx on public.documents (load_id);
create index documents_sync_state_idx on public.documents (sync_state);
create index invoices_user_id_idx on public.invoices (user_id);
create index invoices_load_id_idx on public.invoices (load_id);
create index invoice_revisions_user_id_idx on public.invoice_revisions (user_id);
create index invoice_revisions_invoice_id_idx on public.invoice_revisions (invoice_id);
create index invoice_items_user_id_idx on public.invoice_items (user_id);
create index invoice_items_revision_id_idx on public.invoice_items (invoice_revision_id);
create index invoice_items_source_charge_id_idx on public.invoice_items (source_charge_id);
create index invoice_items_source_document_id_idx on public.invoice_items (source_document_id);
create index payments_user_id_idx on public.payments (user_id);
create index payments_invoice_id_idx on public.payments (invoice_id);
create index tracking_shares_user_id_idx on public.tracking_shares (user_id);
create index tracking_shares_load_id_idx on public.tracking_shares (load_id);
create index tracking_shares_expires_at_idx on public.tracking_shares (expires_at);
create index eta_updates_user_id_idx on public.eta_updates (user_id);
create index eta_updates_load_id_generated_at_idx on public.eta_updates (load_id, generated_at desc);
create index eta_updates_stop_id_idx on public.eta_updates (stop_id);
create index eta_updates_tracking_share_id_idx on public.eta_updates (tracking_share_id);

revoke all on table
  public.vehicles,
  public.customers,
  public.loads,
  public.stops,
  public.trip_events,
  public.charges,
  public.expenses,
  public.documents,
  public.invoices,
  public.invoice_revisions,
  public.invoice_items,
  public.payments,
  public.tracking_shares,
  public.eta_updates
from anon, authenticated, service_role;

grant select, insert, update, delete on table
  public.vehicles,
  public.customers,
  public.loads,
  public.stops,
  public.charges,
  public.expenses,
  public.documents,
  public.invoices,
  public.payments,
  public.tracking_shares,
  public.eta_updates
to authenticated;

grant select, insert on table
  public.trip_events,
  public.invoice_revisions,
  public.invoice_items
to authenticated;

grant select, insert, update, delete on table
  public.vehicles,
  public.customers,
  public.loads,
  public.stops,
  public.trip_events,
  public.charges,
  public.expenses,
  public.documents,
  public.invoices,
  public.invoice_revisions,
  public.invoice_items,
  public.payments,
  public.tracking_shares,
  public.eta_updates
to service_role;

alter table public.vehicles enable row level security;
alter table public.customers enable row level security;
alter table public.loads enable row level security;
alter table public.stops enable row level security;
alter table public.trip_events enable row level security;
alter table public.charges enable row level security;
alter table public.expenses enable row level security;
alter table public.documents enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_revisions enable row level security;
alter table public.invoice_items enable row level security;
alter table public.payments enable row level security;
alter table public.tracking_shares enable row level security;
alter table public.eta_updates enable row level security;
