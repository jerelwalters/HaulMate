# HaulMate P0 Backlog

**Goal:** Ship a closed pilot that proves the complete load-to-cash workflow for a single owner-operator and truck.

**Source:** `docs/PRODUCT_REQUIREMENTS.md` launch MVP 0.1

## Work item model

- **Feature:** A workstream-sized Jira Epic owned as a coherent delivery area.
- **Story:** A demonstrable user, product, or engineering outcome under one feature.
- **Priority:** Every item below is P0 for the closed pilot. Sequence does not change priority.
- **Completion:** A story is done only when its acceptance outcomes pass, relevant checks pass, and Jira-visible evidence is attached or linked.

## Definition of Done

Before a story moves to `Done`, attach or link evidence on the Jira story. Acceptable evidence includes a demo recording, screenshots, passing test output, console output, or clear manual verification steps.

UI-facing stories should include a screenshot or demo unless there is a specific reason they cannot. Domain, backend, release, and documentation stories may use focused test results, command output, health checks, or reproducible verification steps instead.

The completion comment should be brief and include the PR link plus the evidence location or verification summary.

Do not create implementation subtasks until a story is pulled into active work. Split any story that is expected to take more than five focused engineering days.

## Delivery sequence

| Phase | Exit outcome |
|---|---|
| 0. Validate | Pilot cohort and launch platform are confirmed. |
| 1. Foundation | App, backend, CI, auth, ownership, and local persistence are usable. |
| 2. Evaluate | A driver can evaluate and accept a load online or offline. |
| 3. Prove | A driver can run the trip and retain documents and accessorial evidence. |
| 4. Get paid | A driver can generate, send, and reconcile an invoice packet. |
| 5. Pilot | Broker visibility, diagnostics, compliance, and release gates pass. |

## P0-F01 Product and Pilot Readiness

**Outcome:** Confirm that the reachable pilot cohort and workflow justify the selected native client before implementation cost is committed.

| ID | Story | Acceptance outcomes | Depends on | Phase |
|---|---|---|---|---|
| P0-PROD-01 | Confirm pilot cohort and launch platform | Recruit at least 12 representative owner-operators; record device platform and OS, equipment type, factoring use, and availability; document the iOS or Android launch decision and its go/no-go rationale. | None | 0 |
| P0-PROD-02 | Validate the load-to-cash workflow | Walk at least five recruited drivers through evaluate, accept, prove, invoice, and payment scenarios; record current artifacts and top failure points; reconcile findings with the P0 scope without adding unvalidated features. | P0-PROD-01 | 0 |
| P0-PROD-03 | Define the pilot scorecard and feedback loop | Assign a source and review cadence to every business validation goal; define privacy-safe events; provide an in-app feedback and pilot support path. | P0-PROD-02 | 0 |

## P0-F02 Mobile Frontend

**Outcome:** Deliver the complete driver-facing workflow as accessible, testable feature screens. Views depend on injected state and services; they do not call Supabase, storage, analytics, or location APIs directly.

| ID | Story | Acceptance outcomes | Depends on | Phase |
|---|---|---|---|---|
| P0-MOB-01 | Build the app shell and navigation | Provide authenticated and unauthenticated roots; make active-load, modal, and deep-link navigation state restorable and testable; support loading, empty, offline, syncing, failed, and retry states. | P0-PROD-01 | 1 |
| P0-MOB-02 | Build account and business onboarding | Support sign-up, sign-in, password reset, business identity, invoice settings, optional logo, payment terms, and factoring remittance details; validate required invoice fields before completion. | P0-MOB-01, P0-BE-02 | 1 |
| P0-MOB-03 | Build truck and cost profile screens | Capture equipment, MPG, fuel, maintenance reserve, fixed costs, working miles, default fees, and profit target; explain missing inputs and show derived fixed cost per mile. | P0-MOB-01, P0-CORE-02 | 2 |
| P0-MOB-04 | Build dashboard and search | Show active next actions, delivered-not-invoiced work, receivable states, and monthly financial summaries; search the PRD fields; clearly distinguish estimated, billed, and paid values. | P0-CORE-04, P0-CORE-05 | 4 |
| P0-MOB-05 | Build load intake and profitability | Support manual load entry and rate-confirmation attachment; keep deadhead visible; recalculate results immediately; allow per-load default overrides; save evaluating, accepted, or rejected. | P0-MOB-03, P0-CORE-02 | 2 |
| P0-MOB-06 | Build active load, stops, status, and ETA | Show stops, appointment windows, next action, allowed state transitions, arrival/departure, correction history, ETA publishing, and manual location fallback; remain usable offline. | P0-CORE-01, P0-CORE-05, P0-CORE-07, P0-CORE-10 | 3 |
| P0-MOB-07 | Build detention and accessorial evidence | Start detention from arrival in no more than two taps; show free, elapsed, billable, and estimated amounts; capture supported charge types and evidence; require a reason for overrides. | P0-MOB-06, P0-CORE-03 | 3 |
| P0-MOB-08 | Build document capture and library | Scan or import supported images and PDFs; review, rotate, crop, retake, classify, and annotate; show queued, uploading, synced, failed, inspect, and retry states by load. | P0-CORE-08, P0-BE-05 | 3 |
| P0-MOB-09 | Build invoice and payment workflow | Review line items and evidence, warn about missing documents, generate and share a packet, mark sent, and record full, partial, disputed, overdue, and paid states with remaining balance. | P0-MOB-07, P0-MOB-08, P0-CORE-03, P0-CORE-09 | 4 |
| P0-MOB-10 | Build broker visibility controls | Create, preview, share, shorten expiry, and revoke a per-load link; make sharing optional; show exactly which fields the broker can see. | P0-MOB-06, P0-BE-07, P0-WEB-01 | 5 |
| P0-MOB-11 | Build settings, support, and data-rights UI | Edit profile defaults; expose app/device-aware feedback; initiate data export and account deletion with explicit confirmation and status; show privacy and support links. | P0-MOB-02, P0-BE-09, P0-REL-02 | 5 |

## P0-F03 Mobile Core, Offline, and Device Services

**Outcome:** Provide deterministic domain behavior and a durable local-first data layer behind app-owned protocols. The selected mobile stack follows the platform decision in P0-PROD-01.

| ID | Story | Acceptance outcomes | Depends on | Phase |
|---|---|---|---|---|
| P0-CORE-01 | Model the load domain and trip state machine | Define stable UUID-based entities and allowed transitions; preserve immutable trip events and corrections; support cancelled and disputed terminal paths; cover invalid transitions with tests. | P0-PROD-02 | 1 |
| P0-CORE-02 | Implement decimal-safe profitability calculations | Implement every FR-3 formula with decimal-safe arithmetic; expose editable inputs and missing-input errors; cover zero miles, invalid MPG, percentages, rounding, and default overrides with test vectors. | P0-CORE-01 | 2 |
| P0-CORE-03 | Implement detention, invoice, and payment calculations | Apply free time before detention; link charges to evidence; version financial revisions; enforce sequential invoice numbers per account; reconcile partial payments and remaining balance with deterministic tests. | P0-CORE-01 | 3 |
| P0-CORE-04 | Implement local models, migrations, and repositories | Persist the active workflow, profile, recent documents, and sync metadata; use explicit schema migrations; keep UI and domain layers independent of the persistence framework. | P0-CORE-01 | 1 |
| P0-CORE-05 | Implement the durable outbox and synchronization engine | Commit offline mutations locally with idempotency keys; retry after restart and reconnection; expose per-record sync state; prevent duplicate events; require review for financial conflicts. | P0-CORE-04, P0-BE-06 | 1 |
| P0-CORE-06 | Implement secure auth session handling | Store session material in platform-secure storage; restore an authenticated offline session; handle expiry and refresh without losing local work; sign-out does not leak the previous account's data. | P0-BE-02 | 1 |
| P0-CORE-07 | Implement location-backed trip events | Capture UTC, device timezone, latitude, longitude, and accuracy only on explicit active-load actions; label denied, unavailable, poor-accuracy, and manual events truthfully; never claim manual GPS verification. | P0-CORE-01 | 3 |
| P0-CORE-08 | Implement the local document pipeline | Retain a private local original until confirmed upload; validate type/size, process readable images, hash bytes, queue background transfer, retry safely, and prevent analytics or logs from receiving document data. | P0-CORE-04, P0-BE-05 | 3 |
| P0-CORE-09 | Implement versioned invoice PDF generation and sharing | Generate reproducible US Letter invoices from stored data; include selected evidence; create revisions rather than replacing financial history; hand files to the platform share sheet. | P0-CORE-03, P0-CORE-08 | 4 |
| P0-CORE-10 | Implement ETA estimation and navigation handoff | Store manually entered or on-device estimates with source and freshness; hand navigation to the native maps app; never present estimates as truck-safe routing. | P0-CORE-01 | 3 |

## P0-F04 Backend and Security

**Outcome:** Provide an owned Supabase contract with authenticated data, private files, tested row-level authorization, idempotent synchronization, and narrowly scoped public tracking reads.

| ID | Story | Acceptance outcomes | Depends on | Phase |
|---|---|---|---|---|
| P0-BE-01 | Establish backend environments and migration workflow | Create separate local/development and pilot configuration; version schema, policies, functions, and seeds; document reset and deploy commands; keep service credentials out of clients and source control. | P0-PROD-01 | 1 |
| P0-BE-02 | Implement authentication and business profiles | Support email/password registration, reset, session refresh, and profile ownership; store invoice and factoring details; enforce required values server-side where appropriate. | P0-BE-01 | 1 |
| P0-BE-03 | Implement the relational load-to-cash schema | Create constrained tables for vehicles, customers, loads, stops, immutable events/corrections, charges, expenses, documents, invoices/revisions, items, payments, shares, and ETA updates; use client UUIDs and UTC timestamps. | P0-BE-01, P0-CORE-01 | 1 |
| P0-BE-04 | Enforce and test tenant isolation | Enable row-level security on every owned table; scope rows to the authenticated user; prove cross-account reads and writes fail; restrict service-role use to privileged functions. | P0-BE-02, P0-BE-03 | 1 |
| P0-BE-05 | Implement private document storage | Use private buckets and account/load/document object keys; validate metadata and ownership; issue only short-lived signed URLs; prevent permanent or enumerable public access. | P0-BE-03, P0-BE-04 | 3 |
| P0-BE-06 | Define idempotent sync contracts | Accept client UUIDs and idempotency keys; return stable server results for retries; expose update metadata needed for reconciliation; reject invalid state and financial writes without partial corruption. | P0-BE-03, P0-BE-04 | 1 |
| P0-BE-07 | Implement tracking-share lifecycle | Generate at least 128 bits of randomness client-side or server-side as appropriate; persist only token hashes; scope visibility per load/stop; support preview, expiry, shortened expiry, and immediate revocation; default expiry to 72 hours after delivery. | P0-BE-03, P0-BE-04 | 5 |
| P0-BE-08 | Implement the public tracking read contract | Validate the share token in an Edge Function; return only the approved carrier, reference, status, stop, ETA, event, delay, freshness, and POD-availability fields; never expose coordinates, rates, financials, private documents, or authenticated APIs. | P0-BE-07 | 5 |
| P0-BE-09 | Implement account export and deletion | Produce an authenticated export of user-controlled data; revoke shares and sessions; delete or schedule deletion of owned rows and files; report progress and recoverable failures without leaving public access. | P0-BE-04, P0-BE-05 | 5 |

## P0-F05 Broker Tracking Web

**Outcome:** Give a broker a secure, account-free, mobile-friendly status page for exactly one shared load.

| ID | Story | Acceptance outcomes | Depends on | Phase |
|---|---|---|---|---|
| P0-WEB-01 | Build the responsive tracking page | Render carrier display name, load/reference, scoped stops, appointment window, current status, next stop, ETA, arrival/departure events, delay reason, and POD availability from the public contract. | P0-BE-08 | 5 |
| P0-WEB-02 | Represent freshness and ETA honestly | Always show the last successful update; label manual and on-device estimate sources; distinguish loading, current, stale, delayed, delivered, and offline/no-update states; never imply continuous live GPS. | P0-WEB-01 | 5 |
| P0-WEB-03 | Handle secure failure states accessibly | Provide indistinguishable invalid, expired, and revoked responses where security requires it; prevent data from another load appearing during navigation or caching; pass keyboard, screen-reader, text scaling, and WCAG AA checks. | P0-WEB-01, P0-BE-07 | 5 |
| P0-WEB-04 | Deploy and harden the tracking site | Deploy the static TypeScript site to the selected host; configure TLS, security headers, safe caching, environment separation, error monitoring, and a reproducible release command. | P0-WEB-02, P0-WEB-03 | 5 |

## P0-F06 Quality, Compliance, and Pilot Release

**Outcome:** Make the pilot observable, supportable, legally shippable, and resilient enough to run real loads without database intervention.

| ID | Story | Acceptance outcomes | Depends on | Phase |
|---|---|---|---|---|
| P0-REL-01 | Establish source control, builds, and CI gates | Create the app and web projects after the platform decision; configure formatting/build/test jobs and protected secrets; make a clean checkout reproducibly build all pilot artifacts. | P0-PROD-01, P0-BE-01 | 1 |
| P0-REL-02 | Implement privacy-safe analytics, diagnostics, and feedback | Instrument the pilot scorecard and non-sensitive failures; exclude names, load payloads, documents, precise location, invoice details, auth material, and share tokens; include app/version/device context in user-initiated feedback. | P0-PROD-03 | 5 |
| P0-REL-03 | Automate domain, integration, and authorization tests | Cover profitability, detention, invoices, partial payments, state transitions, migrations, sync retries, document policies, share scope, expiry/revocation, and cross-account denial in CI. | P0-CORE-03, P0-BE-08, P0-REL-01 | 5 |
| P0-REL-04 | Prove offline and restart resilience | Test offline create/update, app termination, reconnection, conflict review, interrupted upload, retry, and duplicate-event scenarios on representative devices without data loss. | P0-CORE-05, P0-CORE-08, P0-REL-03 | 5 |
| P0-REL-05 | Pass accessibility and performance gates | Verify critical screens on two representative devices; meet accessible labels, focus, text scaling, and contrast expectations; reach the cached active-load view within three seconds on the chosen representative device. | P0-MOB-11, P0-WEB-03 | 5 |
| P0-REL-06 | Complete privacy, legal, and store readiness | Publish privacy policy, terms, support contact, account-deletion instructions, and accurate store privacy/location disclosures; state product limitations from the PRD; verify all permission prompts are contextual. | P0-BE-09, P0-REL-02 | 5 |
| P0-REL-07 | Prepare and distribute the closed pilot | Configure signing, pilot environments, cost limits, monitoring, TestFlight or the selected Android track, tester onboarding, support ownership, incident contact, and feedback cadence. | P0-REL-04, P0-REL-05, P0-REL-06, P0-WEB-04 | 5 |
| P0-REL-08 | Complete a real load from evaluation to payment | On a production-like pilot build, complete one real load through evaluate, accept, trip events, evidence, invoice, sent, and paid without direct database intervention; record defects and block pilot launch on unresolved data-loss, authorization, or financial errors. | P0-MOB-11, P0-REL-07 | 5 |

## Recommended Jira setup

- **Plan:** Jira Free while the team is 10 users or fewer.
- **Space/project:** Company-managed Scrum project named `HaulMate`, key `HM`.
- **Hierarchy:** Map Feature to Jira `Epic` and Story to Jira `Story`.
- **Statuses:** `Backlog`, `Ready`, `In Progress`, `In Review`, `Blocked`, `Done`.
- **Board filter:** Project `HM`, with quick filters for each workstream label (`mobile`, `core`, `backend`, `web`, `release`).
- **Required fields:** Summary, Work type, Parent, Priority, Labels, Description.
- **Optional after refinement:** Story points, assignee, sprint, and linked blockers. Do not estimate epics.

Import `docs/P0_JIRA_IMPORT.csv` with Jira's external-system CSV importer, mapping `Work item ID`, `Work type`, and `Parent` so the hierarchy is retained. Epic rows appear before their child stories as required by the importer.

## First refinement session

Refine only Phase 0 and Phase 1 initially. Confirm owners, split stories larger than five days, add executable acceptance-test notes, and identify the first vertical slice: sign in -> create business and cost profile -> evaluate a load -> persist offline -> synchronize under row-level security.
