# Database migrations

Create migrations with `supabase migration new <description>`. Keep schema,
constraints, grants, and row-level-security policies together when they form
one deployable behavior change.

Every owned table must enable row-level security. Add authorization tests with
the migration that introduces or changes a policy.
