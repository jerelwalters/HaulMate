# Mobile Auth And Business Profile Contract

This is the backend contract for the MOB-02 follow-up that wires onboarding to
Supabase Auth and `public.business_profiles`.

## Scope

The iOS app owns form state, validation messages, navigation, retry UI, and
secure local session storage. Supabase owns email/password auth, session
refresh, password reset email delivery, and row-level authorization for the
business profile row.

This contract covers:

- Email/password sign-up and sign-in.
- Password reset email requests and callback URL requirements.
- Session refresh and sign-out expectations.
- `business_profiles` read/create/update behavior.
- Client field mapping from `BusinessProfileDraft`.

This contract does not cover:

- Logo upload storage. `logo_storage_path` is reserved for the future storage
  slice.
- Account deletion and export workflows.
- Service-role operations, admin tooling, or pilot data migration.

## Client Configuration

The mobile client uses only public environment values:

| Value | Source | Notes |
|---|---|---|
| Supabase URL | `HAULMATE_SUPABASE_URL` | Local: `http://127.0.0.1:54321`; hosted values come from `supabase/.env.*.local`. |
| Public key | `HAULMATE_SUPABASE_PUBLIC_KEY` | May be labeled publishable or legacy anon by Supabase. Safe for the app. |
| Auth callback URL | `haulmate://auth/callback` | Must be allowlisted in every Supabase environment. |

Never put service-role keys, secret keys, JWT secrets, database passwords, or
storage credentials in the iOS app.

## Auth Flows

### Sign Up

Input:

- `email`
- `password`
- normalized `BusinessProfileDraft`

Expected order:

1. Validate locally using the existing onboarding model.
2. Create the Supabase Auth user with email/password.
3. Read `session.user.id`.
4. Insert `public.business_profiles.user_id = session.user.id` plus the
   normalized business profile fields.
5. Treat either Auth failure or profile insert failure as onboarding failure.

Local and pilot-bootstrap Auth settings disable email confirmation for now, so
sign-up should return a session immediately. If email confirmation is enabled
later, sign-up may return a user without a session; the mobile flow must be
updated before that setting changes.

### Sign In

Input:

- `email`
- `password`

Expected order:

1. Sign in with email/password.
2. Persist the returned session through the app's secure session service.
3. Fetch `business_profiles` for the signed-in user.
4. If no profile is visible, keep the user in onboarding/profile-repair UI.

The app should not pass a `user_id` filter supplied by UI state. It should use
the authenticated session user id when a write payload needs `user_id`, and rely
on RLS for row visibility.

### Password Reset

Input:

- `email`

Expected order:

1. Request a password reset email with redirect URL
   `haulmate://auth/callback`.
2. Handle the incoming deep link in the mobile app.
3. Complete the Supabase recovery session/code exchange required by the Swift
   client.
4. Update the password through Supabase Auth.

The app must not assume a reset request means the email exists. Keep the UI
message generic, for example: "If that email is registered, we sent a reset
link."

### Refresh And Sign Out

Session refresh is part of normal app resume/network retry behavior. If refresh
fails because the session is expired or revoked, route back to unauthenticated
state without showing stale profile data.

Sign out should clear local session material and any cached profile state for
the previous user.

## Business Profile Table

Table: `public.business_profiles`

Ownership:

- `user_id` is the primary key.
- `user_id` references `auth.users(id)` with `on delete cascade`.
- One Auth user has at most one business profile row.

Client access:

- `authenticated` can select, insert, and update.
- `authenticated` cannot delete.
- RLS restricts reads, inserts, and updates to `auth.uid() = user_id`.
- `anon` has no table access.

## Field Mapping

| iOS `BusinessProfileDraft` | Database column | Required | Notes |
|---|---|---:|---|
| `legalName` | `legal_name` | Yes | Trim before write; max 160 chars. |
| `displayName` | `display_name` | No | Trim before write; max 160 chars; send `null` if empty. |
| `mailingAddress` | `mailing_address` | Yes | Trim before write; max 1000 chars. |
| `phone` | `phone` | Yes | Trim before write; max 50 chars. |
| `invoiceEmail` | `invoice_email` | Yes | Trim before write; server checks basic email shape; max 320 chars. |
| `invoicePrefix` | `invoice_prefix` | Yes | Defaults to `HM`; trim before write; max 16 chars. |
| `paymentTermsDays` | `payment_terms_days` | Yes | Defaults to `30`; must be greater than 0. |
| `logoFilename` / `logoImageData` | `logo_storage_path` | No | Reserved. Do not upload or persist logos until storage lands. |
| `usesFactoring` | `uses_factoring` | Yes | Defaults to `false`. |
| `factoringCompanyName` | `factoring_company_name` | Conditional | Required when `uses_factoring` is true; max 160 chars. |
| `factoringRemittanceDetails` | `factoring_remittance_details` | Conditional | Required when `uses_factoring` is true; max 1000 chars. |

Server-owned columns:

| Column | Owner | Notes |
|---|---|---|
| `created_at` | Database | Defaults to `now()`. Client should not set it. |
| `updated_at` | Database | Maintained by trigger. Client should not set it. |

Use `null`, not an empty string, for optional text values that are blank after
trimming. Required values may not be blank.

## Recommended Payloads

Create profile after sign-up:

```json
{
  "user_id": "<session.user.id>",
  "legal_name": "Walters Logistics LLC",
  "display_name": "Walters Logistics",
  "mailing_address": "123 Pilot Way, Detroit, MI 48201",
  "phone": "313-555-0148",
  "invoice_email": "billing@example.com",
  "invoice_prefix": "HM",
  "payment_terms_days": 30,
  "uses_factoring": false,
  "factoring_company_name": null,
  "factoring_remittance_details": null,
  "logo_storage_path": null
}
```

Update profile:

```json
{
  "legal_name": "Walters Transport LLC",
  "display_name": "Walters Transport",
  "mailing_address": "123 Pilot Way, Detroit, MI 48201",
  "phone": "313-555-0148",
  "invoice_email": "billing@example.com",
  "invoice_prefix": "HM",
  "payment_terms_days": 30,
  "uses_factoring": true,
  "factoring_company_name": "Pilot Factoring Co.",
  "factoring_remittance_details": "Send remittance details to billing@example.com",
  "logo_storage_path": null
}
```

Do not update `user_id`. RLS rejects ownership reassignment.

## Error Handling

| Case | Backend behavior | Mobile behavior |
|---|---|---|
| Missing required profile value | Check constraint error | Keep the user in onboarding and show field-level validation. |
| Invalid invoice email | Check constraint error | Show invoice email validation. |
| Factoring enabled without required details | Check constraint error | Show factoring-company and remittance validation. |
| Cross-user read | Row is not visible | Treat as no profile for the current session. |
| Cross-user insert/update | RLS permission error or zero rows updated | Treat as authorization failure, clear stale state, and log non-sensitive diagnostics. |
| Session refresh fails | Auth error | Return to unauthenticated root and clear cached profile state. |

## Verification

Backend verification for this contract:

```sh
supabase/Scripts/verify-local.sh
supabase/Scripts/verify-auth-local.sh
```

`verify-local.sh` rebuilds the local database, applies migrations, runs security
advisors, and runs pgTAP tests for profile constraints and RLS isolation.

`verify-auth-local.sh` proves local Auth health, email/password sign-up,
sign-in, session refresh, sign-out, password reset email request, and local mail
capture.

## Supabase References

- Auth sign-up and redirect behavior:
  <https://supabase.com/docs/reference/swift/auth-signup>
- Auth sign-in with password:
  <https://supabase.com/docs/reference/swift/auth-signinwithpassword>
- Sessions and refresh tokens:
  <https://supabase.com/docs/guides/auth/sessions>
- Native mobile deep linking:
  <https://supabase.com/docs/guides/auth/native-mobile-deep-linking>
- Password-based Auth and reset flow:
  <https://supabase.com/docs/guides/auth/passwords>
- Row Level Security:
  <https://supabase.com/docs/guides/database/postgres/row-level-security>
