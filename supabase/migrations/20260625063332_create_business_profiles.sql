create schema if not exists app_private;

create table public.business_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  legal_name text not null,
  display_name text,
  mailing_address text not null,
  phone text not null,
  invoice_email text not null,
  invoice_prefix text not null default 'HM',
  payment_terms_days integer not null default 30,
  logo_storage_path text,
  uses_factoring boolean not null default false,
  factoring_company_name text,
  factoring_remittance_details text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint business_profiles_legal_name_required
    check (char_length(btrim(legal_name)) > 0),
  constraint business_profiles_legal_name_length
    check (char_length(btrim(legal_name)) <= 160),
  constraint business_profiles_display_name_length
    check (display_name is null or char_length(btrim(display_name)) <= 160),
  constraint business_profiles_mailing_address_required
    check (char_length(btrim(mailing_address)) > 0),
  constraint business_profiles_mailing_address_length
    check (char_length(btrim(mailing_address)) <= 1000),
  constraint business_profiles_phone_required
    check (char_length(btrim(phone)) > 0),
  constraint business_profiles_phone_length
    check (char_length(btrim(phone)) <= 50),
  constraint business_profiles_invoice_email_required
    check (char_length(btrim(invoice_email)) > 0),
  constraint business_profiles_invoice_email_length
    check (char_length(btrim(invoice_email)) <= 320),
  constraint business_profiles_invoice_email_format
    check (invoice_email ~* '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$'),
  constraint business_profiles_invoice_prefix_required
    check (char_length(btrim(invoice_prefix)) > 0),
  constraint business_profiles_invoice_prefix_length
    check (char_length(btrim(invoice_prefix)) <= 16),
  constraint business_profiles_payment_terms_positive
    check (payment_terms_days > 0),
  constraint business_profiles_logo_storage_path_length
    check (
      logo_storage_path is null
      or (
        char_length(btrim(logo_storage_path)) > 0
        and char_length(btrim(logo_storage_path)) <= 1024
      )
    ),
  constraint business_profiles_factoring_company_length
    check (factoring_company_name is null or char_length(btrim(factoring_company_name)) <= 160),
  constraint business_profiles_factoring_remittance_length
    check (factoring_remittance_details is null or char_length(btrim(factoring_remittance_details)) <= 1000),
  constraint business_profiles_factoring_company_required
    check (not uses_factoring or char_length(btrim(coalesce(factoring_company_name, ''))) > 0),
  constraint business_profiles_factoring_remittance_required
    check (not uses_factoring or char_length(btrim(coalesce(factoring_remittance_details, ''))) > 0)
);

comment on table public.business_profiles is
  'One business and invoice profile per Supabase Auth user.';
comment on column public.business_profiles.user_id is
  'Supabase Auth user id. Also the profile primary key for one-to-one ownership.';
comment on column public.business_profiles.logo_storage_path is
  'Optional private storage object path for the business logo once storage lands.';

create or replace function app_private.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_business_profiles_updated_at
before update on public.business_profiles
for each row
execute function app_private.set_updated_at();

revoke all on table public.business_profiles from anon, authenticated, service_role;
grant select, insert, update on table public.business_profiles to authenticated;
grant select, insert, update, delete on table public.business_profiles to service_role;

alter table public.business_profiles enable row level security;
