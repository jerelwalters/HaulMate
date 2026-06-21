# P0 UI and Model Matrix

This file is the implementation contract between the P0 designs, Swift domain
models, local persistence, and the Supabase schema. Figma may explore layout,
but it must not invent states or values outside this contract.

## Core value types

| Concept | Swift/domain type | Server type | UI rule |
|---|---|---|---|
| Identifier | `UUID` | `uuid` | Generated on-device for offline creation. |
| Money | `Decimal` | `numeric(12,2)` | Never calculate with `Double`; show currency to two decimals in detail views. |
| Distance | `Decimal` miles | `numeric(10,1)` | Loaded, deadhead, and total miles remain separately visible. |
| Percentage | `Decimal` | `numeric(7,4)` | Store a ratio; format as a percentage. |
| Instant | `Date` | `timestamptz` | Persist UTC and format in the event's captured timezone. |
| Timezone | IANA identifier `String` | `text` | Retain the device timezone recorded with the event. |
| Appointment window | start/end `Date` | two `timestamptz` values | Show both bounds and the facility timezone. |
| Coordinates | latitude/longitude/accuracy `Double` | numeric values | Never expose coordinates on broker pages. |
| Sync state | `SyncState` enum | outbox/status fields | Show local-only, queued, syncing, synced, failed, and conflict states. |
| Status | feature-specific enums | constrained `text` | CTAs must come from allowed state transitions, not arbitrary buttons. |

## Shared P0 enums

```text
LoadStatus:
evaluating, accepted, enRouteToPickup, atPickup, inTransit, atDelivery,
delivered, invoiced, paid, cancelled, disputed

DocumentType:
rateConfirmation, billOfLading, proofOfDelivery, receipt, lumperReceipt,
invoice, otherEvidence

DocumentSyncState:
localOnly, queued, uploading, synced, failed

InvoiceStatus:
draft, generated, sent, partiallyPaid, paid, disputed

TripEventKind:
statusChanged, arrived, departed, corrected

LocationSource:
deviceVerified, poorAccuracy, unavailable, permissionDenied, manual

ETASource:
onDeviceEstimate, manual

TrackingShareState:
inactive, active, expired, revoked
```

`overdue` is derived when an invoice has a positive remaining balance after its
due date. It is not an independent persisted status.

## Screen-to-model coverage

| P0 screen | Primary models | Required fields and states |
|---|---|---|
| Today | `Load`, `Stop`, `Invoice`, financial summary | Next valid load action, appointment window, estimated profit, delivered-not-invoiced work, outstanding/overdue invoices, offline freshness. |
| Loads and search | `Load`, `Customer`, `Invoice` | Customer/broker, load reference, invoice number, date, load status, payment state. |
| New load | `Load`, `Customer`, `Stop`, `Charge`, `Document` | Broker/customer, reference, line haul, fuel surcharge, pickup/delivery, loaded/deadhead miles, tolls, fees, rate confirmation. |
| Evaluate load | `Load`, `Vehicle`, `Expense`, `Charge` | Revenue, fuel, maintenance, fixed allocation, fees, total cost, profit, margin, revenue per loaded mile, revenue per total mile, missing-input errors, per-load overrides. |
| Active load | `Load`, `Stop`, `TripEvent`, `ETAUpdate` | Allowed transition, appointment window, arrival/departure, timestamp, timezone, location source/accuracy, ETA source/freshness, correction history, sync state. |
| Detention and evidence | `TripEvent`, `Charge`, `Document` | Arrival origin, free minutes, elapsed/billable minutes, rate, estimated amount, override reason, receipts/photos/notes. |
| Documents | `Document`, `SyncOperation` | Type, source, note, local URL/object key, hash, size, captured/imported time, queued/uploading/synced/failed/retry. |
| Invoice ready | `Invoice`, `InvoiceItem`, `Document` | Revision, sequential number, line items, deductions, total, evidence selection, missing-document warnings, generated PDF state. |
| Payment | `Invoice`, `Payment` | Sent date, recipient, due date, payment date, amount, remaining balance, full/partial/disputed states. |
| Broker visibility | `TrackingShare`, `ETAUpdate`, scoped `Stop` data | Visible stops, ETA/source/freshness, expiry, preview, active/expired/revoked state; never rates, profit, expenses, invoices, coordinates, other loads, or private documents. |
| Business setup | `Profile` | Legal/display name, address, phone, email, invoice prefix, terms, optional logo, optional factoring remittance. |
| Truck and cost profile | `Vehicle` and defaults | Equipment, MPG, fuel price, maintenance per mile, monthly fixed costs, working miles, derived fixed cost per mile, default percentage fees, profit target. |
| Settings and data rights | `Profile`, export/deletion request state | Editable defaults, support/feedback context, privacy links, export status, deletion confirmation/status. |

## Design invariants

1. The primary P0 walkthrough uses one coherent load: `HM-1048`, Detroit to
   Columbus, 540 loaded miles, 72 deadhead miles, and 612 total miles.
2. Evaluation uses $1,850 revenue, $1,238 estimated cost, and $612 estimated
   profit. Margin is 33.1%; revenue per total mile is $3.02.
3. The invoice adds $135 detention to the accepted $1,850 commercial terms for
   a $1,985 total due.
4. `Mark arrived` is shown only before an arrival event. `At delivery` is shown
   only after arrival. `Mark delivered` is available only from `atDelivery`.
5. A location is labeled verified only when an explicit trip event contains a
   device location and reported accuracy. Manual events are labeled manual.
6. ETA always shows source and freshness. It is an estimate, never continuous
   live GPS or truck-safe routing.
7. Every mutable offline workflow exposes its sync state. Financial conflicts
   require review rather than silent overwrite.
8. Invoice and payment screens distinguish estimated, billed, sent, paid, and
   remaining amounts.
9. Destructive account and tracking-share actions require explicit confirmation.
10. P1/P2 features such as OCR automation, geofences, continuous tracking,
    accounting integrations, and load-board bidding do not appear in P0 designs.
