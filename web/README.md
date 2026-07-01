# HaulMate Broker Tracking Web

This directory contains the static TypeScript broker tracking page. The P0
surface is a no-login, revocable, per-load view backed by a token-validating
Supabase Edge Function.

The page may display approved status, stop, ETA, delay, freshness, and POD
availability fields. It must not expose rates, profit, expenses, other loads,
precise coordinates, private documents, or privileged credentials.

## Tooling

- `Node.js` runs the local web toolchain.
- `npm` installs packages and runs the commands in `package.json`.
- `Vite` serves the app locally and builds the static `dist/` output.
- `TypeScript` gives the web code compile-time type checking.
- `Vitest` runs unit tests for pure mapping and formatting logic.
- `Playwright` verifies the tracking page in Chromium and WebKit.

## Tracking Contract

`src/tracking/types.ts` defines the public `TrackingResponse` expected from the
`KAN-41` Edge Function. It is intentionally smaller than the backend schema and
contains only broker-visible fields: carrier display name, load reference,
scoped stops, appointment windows, status, ETA, delay reason, freshness, events,
and POD availability.

`src/tracking/fixtures.ts` provides representative responses for UI and tests
while the backend contract is finalized.

## Commands

Install dependencies once:

```sh
npm install
```

Run the local dev server:

```sh
npm run dev
```

Run checks:

```sh
npm run typecheck
npm test
npm run test:e2e
npm run build
```

## Edge Function Configuration

The browser page reads the share token from `?token=`, `?share=`,
`?shareToken=`, or `/track/<token>`, then calls the public tracking Edge
Function with native `fetch`. Configure the endpoint with:

```sh
VITE_HAULMATE_TRACKING_FUNCTION_URL=https://<project-ref>.functions.supabase.co/public-tracking
```

The page never logs the share token or response payload. Invalid, expired, and
revoked links are rendered as the same unavailable-link state.
