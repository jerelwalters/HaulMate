# Tracking API Contract

`KAN-60` defines the browser-facing response shape expected from the `KAN-41`
public tracking Edge Function.

The contract is intentionally narrower than the backend schema. The tracking
page can render carrier identity, load reference, scoped stops, appointment
windows, status, ETA, delay, freshness, events, and POD availability. It must
not receive rates, profit, expenses, invoices, other loads, precise coordinates,
private document data, share tokens, or authenticated API details.

Fixtures in this folder are representative responses for UI and test work until
`KAN-41` is implemented. When the Edge Function contract changes, update these
types and fixtures together.
