# HaulMate backend

Supabase provides Postgres, authentication, private object storage, and Edge
Functions for the pilot. Schema, policies, functions, and deterministic seed
data are version-controlled here; credentials are not.

## Layout

| Path | Purpose |
|---|---|
| `config.toml` | Local Supabase service configuration |
| `.env.example` | Safe template for public client environment values |
| `migrations/` | Ordered schema, policy, and database-function changes |
| `functions/` | Privileged and public Edge Functions |
| `Scripts/` | Local backend verification helpers |
| `docs/` | Backend-to-client contracts and implementation notes |
| `seed.sql` | Deterministic local development data |

## Local workflow

No hosted Supabase organization or project is required for local bootstrap.
Docker Desktop must be running because the CLI starts Supabase as local
containers.

```sh
supabase start
supabase db reset --local
supabase migration new <description>
supabase stop
```

Useful local URLs after `supabase start`:

| Service | URL |
|---|---|
| API | `http://127.0.0.1:54321` |
| Studio | `http://127.0.0.1:54323` |
| Mailpit | `http://127.0.0.1:54324` |
| Database | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` |

Keep `migrations/` reserved for timestamped `.sql` files created by
`supabase migration new <description>`. Keep schema, constraints, grants, and
row-level-security policies together when they form one deployable behavior
change. Every owned table exposed through Supabase must enable row-level
security.

Run the local backend verification check before opening a backend PR:

```sh
supabase/Scripts/verify-local.sh
```

Run the local Auth verification check when changing authentication settings or
mobile onboarding auth flows:

```sh
supabase/Scripts/verify-auth-local.sh
```

That check creates a disposable local user, signs in with email/password,
refreshes the session, signs out, requests a password reset, and verifies the
reset email was captured by the local mail service at
`http://127.0.0.1:54324`.

Backend-to-mobile contracts:

- [`docs/mobile-auth-profile-contract.md`](docs/mobile-auth-profile-contract.md)
- [`docs/document-storage-contract.md`](docs/document-storage-contract.md)
- [`docs/sync-contract.md`](docs/sync-contract.md)
- [`docs/tracking-share-lifecycle-contract.md`](docs/tracking-share-lifecycle-contract.md)

## Environments

Use one local stack plus separate hosted Supabase projects for shared
development and the closed pilot.

| Environment | Purpose | Supabase target | API URL | Local config |
|---|---|---|---|---|
| Local | Fast personal development and reset-heavy testing | Docker containers from `config.toml` | `http://127.0.0.1:54321` | `supabase/.env.local` |
| Development | Shared remote backend for integration testing | `haulmate-dev` (`yroxwdlfgyvufflajmhy`) | `https://yroxwdlfgyvufflajmhy.supabase.co` | `supabase/.env.development.local` |
| Pilot | Closed pilot backend with real tester data | `haulmate-pilot` (`fljfbcmxkxgsytmbdscd`) | `https://fljfbcmxkxgsytmbdscd.supabase.co` | `supabase/.env.pilot.local` |

Copy `supabase/.env.example` to the ignored local file for the environment you
are using. Only public client values belong in those files. Service role keys,
database passwords, JWT secrets, OAuth provider secrets, and storage access
secrets must stay out of source control and out of the iOS app.

```sh
cp supabase/.env.example supabase/.env.local
cp supabase/.env.example supabase/.env.development.local
cp supabase/.env.example supabase/.env.pilot.local
```

Hosted setup requires a Supabase account and organization:

```sh
supabase login
supabase orgs list
supabase projects create haulmate-dev --org-id <org-id> --db-password '<stored-password>' --region us-east-2
supabase projects create haulmate-pilot --org-id <org-id> --db-password '<stored-password>' --region us-east-2
supabase projects list
supabase projects api-keys --project-ref <project-ref>
```

Use `us-east-2` for the initial hosted projects unless the pilot cohort points
to a better region. Store generated database passwords in a password manager.
The API URL and public key are public client config. Depending on the project
and CLI, the public key may be labeled `publishable` or legacy `anon`. The
secret key and service role key are server-only.

Supabase project refs are generated identifiers and are part of the default
`<project-ref>.supabase.co` hostname. Do not assume they can be renamed. A paid
Supabase organization can use an experimental vanity subdomain like
`hm-dev.supabase.co`, or a paid custom domain that HaulMate owns. Treat either
as a separate release decision because Auth callback URLs and app environment
values must be updated together.

```sh
supabase vanity-subdomains check-availability --project-ref yroxwdlfgyvufflajmhy --desired-subdomain hm-dev --experimental
supabase vanity-subdomains check-availability --project-ref fljfbcmxkxgsytmbdscd --desired-subdomain hm-pilot --experimental
```

The CLI links this repo to one hosted project at a time. Linking writes local
state under `supabase/.temp/`, which is ignored.

```sh
supabase link --project-ref <dev-project-ref>
supabase unlink
supabase link --project-ref <pilot-project-ref>
```

When Edge Functions need server-only values, configure them per project:

```sh
supabase secrets set --project-ref <project-ref> NAME=value
supabase secrets list --project-ref <project-ref>
```

Do not run destructive reset or deploy commands against the pilot project
without an explicit release step.

## Migration And Seed Workflow

Treat Supabase migrations like SwiftData schema migrations: each file is an
ordered, reviewed change to the durable backend contract. Create files with the
CLI so names sort correctly:

```sh
supabase migration new <description>
```

Edit the generated SQL file by hand. Keep related schema, constraints, grants,
functions, triggers, and row-level-security policies together when they form one
deployable behavior change. Add pgTAP tests beside the migration when the
change introduces authorization or sync behavior:

```sh
supabase test new <name> --template pgtap
supabase test db --local supabase/tests
```

Before a migration is reviewed, rebuild the local database from scratch:

```sh
supabase/Scripts/verify-local.sh
```

That check resets the local database, applies every migration, runs
`seed.sql`, lists migration state, runs local security advisors, and proves the
database responds to a simple query.

Use `seed.sql` for deterministic local development data only. Seeds must be
safe to run after every `supabase db reset --local`, contain no credentials or
real customer data, and avoid assumptions about hosted dev or pilot state.

Tables that should be reachable through Supabase's Data API must include the
explicit `GRANT` statements for the intended Postgres roles and must still
enable row-level security with policies that match the access model. Treat the
grant, RLS enablement, and policies as one reviewed migration.

## Auth Configuration

Local Auth is configured in `config.toml`. Email/password signups are enabled
for development, email confirmation is disabled for the pilot bootstrap loop,
and password reset emails are caught locally by Supabase's mail service instead
of being sent externally.

The mobile reset/callback redirect is allowlisted as:

```text
haulmate://auth/callback
```

If `config.toml` changes, restart the local stack before verifying Auth so the
GoTrue container picks up the new settings:

```sh
supabase stop
supabase start
supabase/Scripts/verify-auth-local.sh
```

Hosted development and pilot projects need the same Auth settings applied in
Supabase before mobile integration:

- Email provider enabled.
- New signups enabled.
- Email confirmations disabled until the pilot explicitly requires them.
- Minimum password length set to `8`.
- Password requirements set to letters and digits.
- Redirect URL allowlist includes `haulmate://auth/callback`.

## Deployment And Verification

Start every backend release from a clean local rebuild:

```sh
supabase start
supabase/Scripts/verify-local.sh
```

Before any hosted push, confirm the linked project. The BE worktree should
normally stay linked to `haulmate-dev`.

```sh
supabase projects list -o json
supabase migration list --linked
```

Deploy migrations to the hosted development project only after local
verification passes:

```sh
supabase projects list -o json
export SUPABASE_DB_PASSWORD="$(security find-generic-password -a postgres -s "HaulMate Supabase haulmate-dev DB password" -w)"
supabase db push --linked --dry-run
supabase db push --linked
supabase migration list --linked
set -a; source supabase/.env.development.local; set +a
curl --fail --silent --show-error \
  -H "apikey: $HAULMATE_SUPABASE_PUBLIC_KEY" \
  "$HAULMATE_SUPABASE_URL/auth/v1/health"
unset SUPABASE_DB_PASSWORD
```

Deploying to pilot is an explicit release step. Link to `haulmate-pilot`,
dry-run first, apply only after reviewing the dry-run output, verify health,
then link back to development:

```sh
export SUPABASE_DB_PASSWORD="$(security find-generic-password -a postgres -s "HaulMate Supabase haulmate-pilot DB password" -w)"
supabase link --project-ref fljfbcmxkxgsytmbdscd --password "$SUPABASE_DB_PASSWORD"
supabase projects list -o json
supabase db push --linked --dry-run
supabase db push --linked
supabase migration list --linked
set -a; source supabase/.env.pilot.local; set +a
curl --fail --silent --show-error \
  -H "apikey: $HAULMATE_SUPABASE_PUBLIC_KEY" \
  "$HAULMATE_SUPABASE_URL/auth/v1/health"
unset SUPABASE_DB_PASSWORD

export SUPABASE_DB_PASSWORD="$(security find-generic-password -a postgres -s "HaulMate Supabase haulmate-dev DB password" -w)"
supabase link --project-ref yroxwdlfgyvufflajmhy --password "$SUPABASE_DB_PASSWORD"
unset SUPABASE_DB_PASSWORD
```

Do not push seeds to pilot. If a dry-run looks wrong or a hosted push fails,
stop and fix the issue with a follow-up migration. Do not patch pilot manually.

Keep `SUPABASE_DB_PASSWORD` process-local. Do not write database passwords to
`.env.*.local`, `.env.example`, source files, docs, or the iOS app.

Completion evidence for this backend setup is:

- `supabase/Scripts/verify-local.sh` passes locally.
- `supabase/Scripts/verify-auth-local.sh` passes locally after Auth config
  changes.
- `supabase db push --linked --dry-run` passes for development.
- `supabase migration list --linked` matches the expected migration state.
- `/auth/v1/health` succeeds for the target hosted environment using the
  public API key header.
- Pilot deployment commands are documented, but pilot is changed only during an
  explicit release step.
