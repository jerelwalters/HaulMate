# HaulMate iOS Networking

## Feature Overview

HaulMate should use a dedicated networking boundary before wiring remote
endpoints into the iOS app. The boundary should make routine JSON calls easy,
keep request and response models strongly typed, and avoid coupling feature UI,
repositories, or domain models to a specific transport library.

The intended module is `NetworkingModule`, parallel to `AuthorizationModule` and
`StorageModule`. It owns generic HTTP transport concerns only. Auth, profile,
load sync, document storage, and Supabase-specific behavior remain in app-owned
service protocols and adapter implementations.

## Business Context

The pilot needs fast Supabase integration without turning the app into a
Supabase-shaped codebase. Mobile tickets should be able to wire auth, profiles,
sync, storage, and Edge Functions while preserving the option to replace
transport details later.

This matters for:

- keeping SwiftUI screens focused on user workflows;
- preserving repository testability;
- isolating Supabase SDK types from app models;
- allowing a future `URLSession` to Alamofire transport swap without changing
  repositories or feature code;
- supporting the later durable outbox and offline-first sync design.

## High-Level Design

```text
Feature UI
  -> Repository
    -> app-owned service protocol
      -> implementation or vendor adapter
        -> NetworkingModule HTTPClient or vendor SDK
```

Rules:

- Feature UI never imports `NetworkingModule`, Supabase, Alamofire, or any
  endpoint adapter.
- Repositories depend on app-owned service protocols and app-owned models.
- Service and vendor adapters own remote calls, DTO mapping, auth headers, retry
  policy, and error translation.
- `NetworkingModule` provides generic HTTP request execution and typed Codable
  encoding/decoding.
- Supabase SDK types, Alamofire types, and raw `URLSession` details do not cross
  the adapter boundary.

## Low-Level Design

The generic transport surface should be small:

```swift
public protocol HTTPClient: Sendable {
    func send<Response: Decodable & Sendable>(
        _ request: HTTPRequest<Response>
    ) async throws -> Response
}
```

`HTTPRequest<Response>` should describe the transport request with
Foundation-friendly fields:

- HTTP method;
- path or URL;
- query items;
- headers;
- optional body;
- response decoder strategy.

Body construction should support generic Codable payloads without assuming every
network operation is JSON:

```swift
public enum HTTPBody: Sendable {
    case json(Data)
    case raw(Data, contentType: String)
}

extension HTTPBody {
    public static func json<Request: Encodable>(
        _ request: Request,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> Self {
        .json(try encoder.encode(request))
    }
}
```

The default implementation should be `URLSessionHTTPClient`. If Alamofire is
introduced later, it should live behind a separate `AlamofireHTTPClient` adapter
that implements the same `HTTPClient` protocol.

```text
HTTPClient
  <- URLSessionHTTPClient
  <- AlamofireHTTPClient
```

Swapping implementations should change composition only. It should not require
changes to feature views, repositories, domain models, or app-owned service
protocols.

## Supabase Integration Boundary

Supabase remains the backend choice for the pilot. Mobile integration should use
app-owned protocols such as auth, profile, sync, load remote store, and document
store boundaries.

The adapter can choose the best implementation detail:

- use `supabase-swift` when the SDK removes meaningful Auth, PostgREST, Storage,
  session, or RPC work;
- use `NetworkingModule` for HaulMate-owned JSON endpoints, Edge Functions, or
  lightweight REST calls;
- map all remote DTOs and vendor errors into HaulMate-owned models and errors
  before returning to repositories.

Do not expose Supabase request builders, table names, SDK sessions, Alamofire
requests, or transport errors through repository or feature APIs.

## Error Handling

`NetworkingModule` should report transport-level failures in app-owned error
types. Adapters should translate those into domain-specific service failures.

Examples:

- connectivity or timeout;
- invalid URL or request construction;
- non-2xx HTTP status with optional response body;
- decoding failure;
- authorization failure detected from status or vendor error mapping.

Repositories should continue mapping service failures into user-facing states or
action results.

## Current State

This is a design decision for upcoming mobile endpoint work. The app currently
uses repository and storage/auth package boundaries, but there is no dedicated
`NetworkingModule` yet.

When the first remote endpoint ticket is pulled, add the module with focused
tests for:

- request URL and query construction;
- header and body encoding;
- Codable response decoding;
- non-2xx response handling;
- transport-library isolation.

## Risks and Edge Cases

- Do not build a broad networking framework before the first real endpoint
  needs it.
- Keep uploads, downloads, progress reporting, and background transfer as
  separate capabilities instead of forcing them through the basic JSON client.
- Keep retry and durable outbox behavior above raw transport. The outbox owns
  idempotency, replay, and conflict handling.
- Avoid leaking vendor-specific errors into domain or UI state.
- Avoid hiding Supabase RLS or Auth behavior behind a fake local-only success
  path during integration.

## Ticket Guidance

Future mobile endpoint tickets should reference this page and follow this order:

1. Define or confirm the app-owned service protocol.
2. Add DTOs and adapter mapping for the remote contract.
3. Use `NetworkingModule` or a vendor SDK inside the adapter only.
4. Inject the adapter at the composition root.
5. Test repository behavior with mock services and adapter mapping with focused
   network/client tests.
