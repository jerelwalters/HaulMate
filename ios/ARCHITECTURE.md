# HaulMate Architecture

## Dependency rule

```text
Feature UI -> Repository -> app-owned service protocol <- implementation adapter
                                                       <- vendor adapter
```

- Feature UI knows repositories, domain models, and UI-owned navigation only.
- Repositories expose observable app state and operations to feature UI.
- Repositories depend on app-owned service protocols, never vendor SDK types.
- Service implementations own concurrency, persistence, networking, and SDK calls.
- Vendor adapters live under `HaulMate/Infrastructure/Vendors/<Vendor>`.
- The composition root is the only layer allowed to select concrete adapters.

`AuthRepository` lives in `AuthorizationModule` and is the app-facing auth
boundary. It exposes `authStatus` for app root routing plus sign-in, sign-up,
profile, password reset, and sign-out operations. `AuthSessionManager` is an
internal module implementation detail that owns auth session lifecycle
orchestration through injected storage, refresh, and cleanup protocols.
Supabase Auth types must stay inside a future vendor adapter or manager mapping
layer; the app target should keep using HaulMate auth models only.

## Offline-first target

HaulMate is structured to become offline-first, but the current app shell is not
offline-first yet. It currently persists navigation state only.

```text
Feature UI -> Repository -> Local store
                         -> Durable outbox -> Sync engine -> Remote adapter
```

- The local store is the source of truth for active workflows.
- Mutations commit locally before network synchronization begins.
- A durable outbox owns idempotency, retries, and recovery after relaunch.
- Repositories expose stable app models and per-record synchronization state.
- Conflicts are resolved by app-owned policy or surfaced for user review.
- The remote backend remains an adapter and is never required for local UI reads.

SwiftData models and migrations, the durable outbox, the sync engine, and conflict
handling still need to be implemented before the app can claim offline-first
behavior.

## Layer responsibilities

### Feature UI

- SwiftUI layout, presentation state, and user actions.
- Reads repositories through the app environment or explicit injection.
- Never imports a third-party package or references service implementations.

### Repository

- A main-actor `@Observable` reference type when it publishes UI state.
- Accepts an app-owned service protocol through an explicit initializer.
- May provide a convenience initializer only for a vendor-neutral default.
- Maps service errors and results into stable app-owned state.

### Service protocol

- Declared and owned by HaulMate.
- Uses only app-owned models and standard-library/Foundation types.
- Is `Sendable` when calls cross an actor boundary.

### Implementation adapter

- Prefer actors for mutable service-side state.
- Implements an app-owned service protocol.
- Maps vendor DTOs, errors, identifiers, and callbacks before returning.
- Does not expose SDK types through protocol signatures or domain models.

## Adding a package or pod

1. Add the dependency only to a dedicated adapter target or vendor folder.
2. Define the required behavior in an app-owned service protocol.
3. Implement that protocol in the vendor adapter.
4. Inject the adapter into the repository at the composition root.
5. Test repository behavior with a mock service and adapter mapping separately.

Switching vendors should require replacing an adapter, not changing feature UI.

## Enforcement

`Scripts/check_architecture.sh` runs during every app build. It currently ensures:

- Feature UI and `AppRootView` do not reference `AuthService`.
- The app target does not reference `AuthSessionManager`; construction goes
  through `AuthRepository`.
- Feature UI imports only approved system frameworks.
- Repository files import only Foundation and Observation.

Update the guard only as part of a deliberate architecture change.

## Source ownership

App-owned Swift, test, and script files begin with:

```text
Created by Jerel Walters on <creation date>.
Copyright © <creation year> Jerel Walters. All rights reserved.
```

Generated project metadata, configuration files, and documentation are excluded.
The architecture guard enforces this convention for owned source files.
