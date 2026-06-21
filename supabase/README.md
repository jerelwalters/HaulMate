# HaulMate backend

Supabase provides Postgres, authentication, private object storage, and Edge
Functions for the pilot. Schema, policies, functions, and deterministic seed
data are version-controlled here; credentials are not.

## Layout

| Path | Purpose |
|---|---|
| `config.toml` | Local Supabase service configuration |
| `migrations/` | Ordered schema, policy, and database-function changes |
| `functions/` | Privileged and public Edge Functions |
| `seed.sql` | Deterministic local development data |

## Local workflow

Docker must be running.

```sh
supabase start
supabase db reset
supabase migration new <description>
```

Use separate Supabase projects for development and the pilot. Store local
values in ignored `.env.local` files and configure hosted secrets with the
Supabase CLI or dashboard.
