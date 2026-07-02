# Public Tracking Read Contract

P0-BE-08 owns the public read boundary for broker tracking links.

## Request

Call the `public-tracking` Edge Function with `GET`:

```text
/functions/v1/public-tracking?token=<share-token>
```

The endpoint is public because brokers do not have HaulMate accounts. The token
is the credential, so invalid, expired, revoked, or malformed access returns the
same generic unavailable response.

## Response

The Edge Function calls `public.read_public_tracking_share(token)` with the
service role. That RPC returns the web `TrackingResponse` shape:

- `carrier.displayName`
- `load.referenceNumber`, `status`, `currentStopId`, `nextStopId`
- scoped `stops`
- current `eta`
- optional `latestDelay`
- `pod` availability only, never document URLs or paths
- `freshness`
- public `events`

## Privacy Boundary

The response must not include:

- plaintext share tokens or token hashes
- user/account/auth/session identifiers
- coordinates or accuracy
- raw stop addresses
- rates, profit, costs, expenses, invoices, payments, or other financial data
- private document metadata, object paths, or signed URLs
- other loads

Stop `city` and `region` are optional structured public locality fields. Raw
addresses stay private even when a stop is visible.
