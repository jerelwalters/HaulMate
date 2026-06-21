# Edge Functions

Use Edge Functions only for operations that require a service credential or a
narrow public contract, such as validating a tracking-share token.

Never expose the Supabase service role key to the iOS app or broker web page.
Shared function-only helpers should live under `functions/_shared/` once the
first function is implemented.
