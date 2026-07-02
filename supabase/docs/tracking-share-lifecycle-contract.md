# Tracking Share Lifecycle Contract

P0-BE-07 owns the authenticated backend lifecycle for broker visibility links.
The public read contract is separate and remains owned by P0-BE-08.

## Token Rules

- `create_tracking_share` generates a URL-safe 256-bit token server-side.
- The plaintext token is returned once in the create response.
- Durable rows store only `tracking_shares.token_hash`, a SHA-256 hash.
- Preview, shorten, and revoke responses never return token material.

## Create

Call `public.create_tracking_share` as an authenticated user.

| Name | Type | Required | Notes |
|---|---|---:|---|
| `share_id` | UUID | No | Client-generated ID when the app needs a stable local reference. Null lets the server generate one. |
| `load_id` | UUID | Yes | Must belong to the authenticated user. |
| `stop_scope` | Text | No | `pickup`, `delivery`, or `all`. Defaults to `all`. |
| `visibility` | JSON object | No | Optional booleans: `show_carrier_name`, `show_reference_number`, `show_stops`, `show_eta`, `show_pod_availability`. Missing values default to true. |
| `expires_at` | Timestamp | No | Optional shortened expiry. It must be in the future and cannot extend beyond the default delivery window. |

If `expires_at` is omitted before delivery, the row keeps `expires_at = null`.
The effective default expiry is computed as `loads.delivered_at + 72 hours`
once delivery exists. If the load is already delivered, create stores that
default expiry immediately.

The create response includes:

```json
{
  "share_id": "00000000-0000-0000-0000-000000000000",
  "load_id": "00000000-0000-0000-0000-000000000000",
  "token": "url-safe-token-returned-once",
  "token_bits": 256,
  "state": "active",
  "stop_scope": "delivery",
  "expires_at": null,
  "effective_expires_at": null,
  "revoked_at": null,
  "visibility": {
    "show_carrier_name": true,
    "show_reference_number": true,
    "show_stops": true,
    "show_eta": true,
    "show_pod_availability": true
  },
  "visible_stops": []
}
```

## Preview

Call `public.preview_tracking_share(share_id)` as the owner. The response is
the owner-facing share preview and intentionally excludes `token` and
`token_hash`.

Preview returns the share state (`active`, `expired`, or `revoked`), scoped
stops, non-financial load identity, visibility flags, and expiry information.

## Shorten Expiry

Call `public.shorten_tracking_share_expiry(share_id, expires_at)` as the owner.
The new timestamp must be in the future and must shorten the current effective
expiry when one exists. This RPC never extends access.

## Revoke

Call `public.revoke_tracking_share(share_id)` as the owner. Revocation is
immediate and idempotent; a previously revoked share remains revoked.

## Security Rules

- Anonymous users cannot execute lifecycle RPCs.
- Authenticated users can operate only on shares for their own loads.
- `app_private` token helpers are not executable by clients.
- Public viewer token validation and response field filtering belong to
  P0-BE-08.
