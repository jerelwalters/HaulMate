# HaulMate broker tracking web

This directory will contain the static TypeScript broker tracking page. The P0
surface is a no-login, revocable, per-load view backed by a token-validating
Supabase Edge Function.

The page may display approved status, stop, ETA, delay, freshness, and POD
availability fields. It must not expose rates, profit, expenses, other loads,
precise coordinates, private documents, or privileged credentials.

The project toolchain will be selected and initialized with `P0-WEB-01`; no web
runtime dependency is needed for the repository bootstrap.
