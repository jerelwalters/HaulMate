# Edge Functions

Use Edge Functions only for operations that require a service credential or a
narrow public contract, such as validating a tracking-share token.

Never expose the Supabase service role key to the iOS app or broker web page.
Shared function-only helpers should live under `functions/_shared/` once the
first function is implemented.

## Functions

| Function | Purpose |
|---|---|
| `document-signed-url` | Validates an owned synced document through RLS and returns a 300-second signed Storage URL. |
| `public-tracking` | Public GET endpoint for broker tracking links. Validates the share token through a service-role-only RPC and returns only the approved tracking response fields. |
