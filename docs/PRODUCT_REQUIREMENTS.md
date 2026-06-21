# HaulMate Product Requirements

**Version:** Launch MVP 0.1
**Status:** Draft for implementation
**Updated:** June 19, 2026

## 1. Product decision

HaulMate will launch as a **load-to-cash assistant for independent box-truck and semi-truck owner-operators**.

The first release will help a driver:

1. Decide whether a load is profitable.
2. Keep the load's documents and expenses together.
3. Record pickup, delivery, detention, and exceptions with time and location evidence.
4. Build a complete invoice packet immediately after delivery.
5. Track whether the invoice has been sent and paid.
6. Give the broker a self-service ETA and load-status view without exposing the operator's business data.

**Product promise:** Know whether the load pays, prove what happened, and invoice before leaving the receiver.

## 2. Problem

Owner-operators use text messages, email, paper, photo galleries, spreadsheets, load boards, and accounting tools to complete one job. This fragmented workflow causes:

- Unprofitable loads accepted without accounting for deadhead, fuel, tolls, time, and maintenance.
- Lost rate confirmations, BOLs, PODs, receipts, and accessorial evidence.
- Unpaid detention, lumper, layover, extra-stop, and truck-ordered-not-used charges.
- Repeated broker calls and messages asking for pickup status, delivery status, and ETA.
- Late or rejected invoices.
- Poor visibility into actual per-load profit and unpaid receivables.

HaulMate will not attempt to fix freight rates or replace every trucking product. It will close the workflow between evaluating a load and collecting payment.

## 3. Target customer

### Primary user

An independent owner-operator who owns or leases one box truck or tractor, finds freight through brokers or direct customers, drives the load, manages paperwork, and invoices without dedicated back-office staff.

### Initial operating profile

- One driver and one truck.
- United States operations.
- Dry freight and general cargo.
- Uses a smartphone as the primary business device.
- May have unreliable connectivity at facilities or on the road.
- Sends invoices directly or prepares packets for a factoring company.

### Secondary viewer

A broker, dispatcher, or direct customer who receives a secure link for one load and needs its current status, pickup or delivery ETA, and completion evidence. This viewer does not need a HaulMate account in the MVP.

### Not targeted in the MVP

- Fleet dispatch teams and multi-driver permissions.
- Carrier payroll or driver settlements.
- Full broker, shipper, or dispatch-management accounts.
- Hazmat, reefer telemetry, oversize permits, or specialized compliance workflows.

## 4. Product goals

### User goals

- Evaluate a load in less than 60 seconds once its basic details are entered.
- Keep all load documents and evidence in one record.
- Begin a detention record in two taps or fewer from the active load.
- Generate a complete invoice packet within five minutes of delivery.
- See outstanding receivables and estimated profit without a spreadsheet.
- Reduce routine broker check calls by providing a current status and ETA link.

### Business validation goals

During the closed pilot:

- Recruit at least 12 owner-operators and retain 8 weekly active testers.
- Record at least 50 real loads from acceptance through invoice.
- Have at least 70% of completed loads generate an invoice packet.
- Reduce median delivery-to-invoice time to less than 30 minutes.
- Recover or document at least 10 accessorial charge events.
- Have brokers open a shared status page for at least 50% of tracked pilot loads.
- Reduce driver-reported pickup and delivery check calls on shared loads.
- Convert at least 3 pilot users to a paid monthly plan or obtain equivalent signed purchase intent.

## 5. Core workflow

1. The operator creates a load and enters or imports its rate confirmation.
2. HaulMate calculates expected cost, profit, margin, and revenue per total mile.
3. The operator accepts or rejects the load outside HaulMate and marks the decision.
4. For an accepted load, the operator adds stops and required documents and can share a broker visibility link.
5. At the start of a leg, the operator publishes an ETA calculated on-device or enters one manually.
6. At each stop, the operator records arrival and departure. HaulMate captures device time and location with permission.
7. The shared broker page updates with status, ETA, delay, and last-update time.
8. The operator photographs or imports the BOL, POD, receipts, and exception evidence.
9. HaulMate calculates detention and other approved accessorials.
10. At delivery, HaulMate checks packet completeness and generates an invoice PDF.
11. The operator shares the invoice packet using the phone's share sheet and marks it sent.
12. The operator records payment, partial payment, or a dispute.

## 6. Launch requirements

Priority definitions:

- **P0:** Required for the closed pilot.
- **P1:** Build after the workflow is validated.
- **P2:** Explicitly deferred.

### FR-1 Account and business profile (P0)

The operator can:

- Create an account with email and password.
- Reset a forgotten password.
- Enter legal/business name, address, phone, email, invoice prefix, payment terms, and optional logo.
- Enter factoring-company remittance details when applicable.
- Export account data and request account deletion.

**Acceptance criteria**

- Business details populate every generated invoice.
- A user can access only their own loads, documents, and settings.
- The app remains usable for an already authenticated user during a temporary network outage.

### FR-2 Truck and cost profile (P0)

The operator can save:

- Equipment type: box truck or tractor-trailer.
- Average fuel economy.
- Default fuel price.
- Maintenance reserve per mile.
- Monthly fixed truck costs and estimated working miles per month.
- Default toll, dispatch, factoring, and other percentage-based costs.
- Target profit per load or target revenue per total mile.

**Acceptance criteria**

- HaulMate derives a fixed-cost allocation per mile from monthly cost and working miles.
- Every calculated value shows the inputs used and remains editable for a specific load.
- Missing inputs produce an explanation, not a misleading zero-cost estimate.

### FR-3 Load intake and profitability (P0)

The operator can:

- Create a load manually.
- Attach a PDF or photo rate confirmation.
- Enter broker/customer, reference number, line-haul rate, fuel surcharge, pickup and delivery stops, loaded miles, deadhead miles, and estimated tolls.
- Add flat or percentage fees and expected accessorials.
- See gross revenue, estimated operating cost, estimated profit, margin, revenue per loaded mile, and revenue per total mile.
- Save the load as evaluating, accepted, or rejected.

The calculation must use:

```text
total miles = loaded miles + deadhead miles
fuel cost = total miles / miles per gallon * fuel price
maintenance cost = total miles * maintenance reserve per mile
fixed cost allocation = total miles * fixed cost per mile
estimated profit = gross revenue - all estimated costs and fees
revenue per total mile = gross revenue / total miles
```

**Acceptance criteria**

- Results recalculate immediately when an input changes.
- Loaded and deadhead miles are never combined invisibly.
- The user can override a default without changing their saved cost profile.
- The original rate confirmation remains attached to the load.

### FR-4 Stops and trip state (P0)

The operator can move a load through:

```text
Evaluating -> Accepted -> En route to pickup -> At pickup -> In transit
-> At delivery -> Delivered -> Invoiced -> Paid
```

The operator can also mark a load cancelled or disputed.

For pickup, delivery, and extra stops, the operator can:

- Save the facility, address, appointment window, contact, and notes.
- Tap Arrived and Departed.
- Allow HaulMate to attach device timestamp, timezone, latitude, longitude, and reported location accuracy to those events.
- Correct a mistaken status while preserving the original event in the audit history.

**Acceptance criteria**

- Status changes and evidence can be captured offline and sync later.
- The app clearly identifies events recorded without location permission or a reliable GPS fix.
- HaulMate never claims that a manually recorded event is GPS-verified.

### FR-5 Detention and accessorial evidence (P0)

The operator can:

- Save free-time minutes and detention rate from the rate confirmation.
- Start detention from an arrival event or manually.
- See elapsed, billable, and estimated detention amounts.
- Add lumper, layover, extra-stop, redelivery, cancellation, and other charges.
- Attach receipts, photos, check-in numbers, dock numbers, notes, and contact names.
- Override a calculated amount with a reason.

**Acceptance criteria**

- Billable detention does not begin until free time expires.
- Any change to an evidence event or calculated amount is retained in the audit history.
- The invoice packet links each accessorial amount to its supporting evidence.

### FR-6 Document capture and organization (P0)

Supported document types are rate confirmation, BOL, POD, receipt, lumper receipt, invoice, and other evidence.

The operator can:

- Capture a document with the camera or import an image/PDF.
- Assign a document type and optional note.
- Review, rotate, crop, and retake a capture before upload.
- See queued, uploading, synced, and failed states.
- Retry failed uploads.
- View all documents under the associated load.

**Acceptance criteria**

- The app stores a local copy until upload succeeds.
- Images are compressed for readability and cost, while the user can inspect the result before accepting it.
- Private documents are never exposed by a permanent public URL.
- Each stored file records its hash, capture/import time, uploader, and associated load.

### FR-7 Invoice packet (P0)

The operator can:

- Generate a sequential invoice number.
- Review billed line haul, surcharge, accessorials, deductions, and total due.
- Select supporting documents for the packet.
- See missing-document warnings before generation.
- Generate a US Letter PDF invoice.
- Share the invoice and supporting documents through the device share sheet.
- Record sent date, recipient, due date, payment status, amount paid, and dispute notes.

**Acceptance criteria**

- A generated invoice is reproducible from stored load and business data.
- Regenerating after a financial change creates a revision and does not silently replace the prior invoice.
- A load cannot be marked paid without an amount and payment date.
- Partial payments leave the remaining balance visible.

### FR-8 Dashboard and search (P0)

The operator can:

- See active loads and the next required action.
- See delivered loads that are not invoiced.
- See invoices that are unpaid, overdue, paid, or disputed.
- Search by customer, broker, load/reference number, invoice number, and date.
- See monthly gross revenue, estimated profit, accessorials billed, and outstanding receivables.

**Acceptance criteria**

- Financial summaries reconcile to the visible load records.
- Estimated values are labeled separately from paid or actual values.
- The active-load screen is available offline from the most recent sync.

### FR-9 Broker visibility link (P0)

For an accepted load, the operator can:

- Create a secure, unguessable, revocable link for that load.
- Choose whether the link shows pickup, delivery, or both.
- Publish an ETA calculated on-device or entered manually.
- Refresh or override the ETA and add a short delay reason.
- Preview exactly what the external viewer will see.
- Copy or share the link using the system share sheet.
- Revoke the link at any time.

Without creating an account, the broker can see:

- Carrier display name and load/reference number.
- Current load status and next stop.
- Pickup or delivery appointment window.
- Current ETA, its source, and when it was last refreshed.
- Arrival and departure times after those events occur.
- A driver-provided delay reason.
- Whether POD is available after delivery.

The broker cannot see rates, profitability, expenses, invoices, other loads, the driver's precise current coordinates, or private documents unless the operator explicitly shares a specific document.

**Acceptance criteria**

- The link contains at least 128 bits of randomness, is stored server-side as a hash, and can be revoked immediately.
- The default expiration is 72 hours after delivery; the operator can shorten it.
- The page always shows its last successful update time and never presents a stale ETA as live.
- An on-device route estimate is labeled as an estimate and is not represented as truck-safe routing.
- Status changes made in the app appear on the external page after synchronization.
- Viewing the page never grants access to the authenticated app API or another load.
- The operator can complete the full load workflow without enabling external visibility.

### FR-10 Pilot feedback and support (P0)

- The settings screen provides a feedback link with app version and device details.
- The app records non-sensitive error diagnostics.
- Analytics never include document contents, precise location, invoice details, or customer names.

## 7. Next requirements

### P1: after pilot validation

- On-device OCR for images, with user-reviewed suggestions for load fields.
- Geofence-assisted arrival and departure while a load is active.
- Opt-in background location sessions and periodically refreshed ETA for shared loads.
- Broker update requests with driver push notifications.
- Automated invoice email and delivery status.
- Authenticated broker dashboard for viewing multiple shared loads.
- Broker/customer directory and lane history.
- Settlement upload and invoice comparison.
- Recurring maintenance reminders.
- Multiple trucks and team members.
- Web back-office view.

### P2: defer until product-market evidence

- Load-board marketplace or automated bidding.
- ELD or hours-of-service system of record.
- Truck navigation and parking marketplace.
- Broker credit, authority, bond, and fraud verification.
- IFTA filing and jurisdiction mileage reports.
- Direct bank connections, bookkeeping, payroll, or tax filing.
- Reefer telemetry, hazmat, oversize, or permit workflows.
- Fully automated AI extraction without user verification.

## 8. Offline and sync behavior

- The server is the source of truth after successful synchronization.
- The active load, stops, recent documents, and user profile are cached locally.
- Offline mutations receive a client-generated UUID and enter a durable outbox.
- The outbox retries when connectivity returns and uses idempotency keys to prevent duplicates.
- Financial conflicts require explicit user review; they are never silently overwritten.
- Document uploads resume or retry without losing the local original.
- The UI always shows whether a value is local-only, syncing, synced, or failed.

## 9. Security and privacy

- All network traffic uses TLS.
- Database row-level security enforces per-user ownership.
- Document storage is private and served only with short-lived signed access.
- Authentication tokens use encrypted device storage.
- Backend service credentials are never bundled into the mobile app.
- Location is collected only after clear permission and only for an active load event in the MVP.
- External visibility is disabled by default, scoped to one load, revocable, and expires automatically.
- Shared pages expose status and ETA rather than raw GPS coordinates in the MVP.
- The user can still record an event when location is denied.
- Sensitive values are excluded from analytics and crash reports.
- Account deletion removes or schedules deletion of user-controlled data and documents.
- HaulMate is not an ELD, accounting system of record, legal service, or guarantee that an accessorial charge will be paid.

## 10. Quality requirements

- Support the current and previous major versions of Android and iOS at public launch.
- Cold launch should reach the usable active-load view within three seconds on a representative mid-range device after initial setup.
- Core text and controls meet WCAG AA contrast and mobile accessibility labeling expectations.
- Financial calculations use decimal-safe arithmetic and are covered by unit tests.
- Time records retain UTC time, device timezone, and original capture metadata.
- The app must not lose an accepted document or trip event during a network interruption or app restart.
- Background activity is not required for the P0 workflow.

## 11. Release gates

The closed pilot can begin when:

- All P0 workflows function on at least two representative devices for the selected launch platform.
- Profit calculations, invoice totals, partial payments, and detention calculations pass automated tests.
- Offline creation, app restart, reconnection, upload retry, and duplicate-event scenarios pass.
- Database ownership policies pass cross-account access tests.
- Privacy policy, terms, account deletion, support contact, and store disclosures are present.
- At least one real load completes the full create-to-paid workflow without direct database intervention.

The public launch can begin after:

- Pilot success metrics are reviewed.
- Crash-free session rate is at least 99.5% during the final pilot period.
- Store testing and identity-verification requirements are complete.
- Production backups, monitoring, cost alerts, and an incident contact are configured.
