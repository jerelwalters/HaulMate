//
//  Created by Jerel Walters on 6/22/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

/// A published arrival estimate for one load, and optionally for one specific stop.
///
/// This model does not calculate a route. It records the ETA the operator is willing
/// to publish, where the estimate came from, and when that estimate was generated.
/// Freshness is based on the age of the estimate, not on how close the truck is to
/// the destination:
///
/// `estimate age = date being checked - generatedAt`
///
/// If that age is inside `staleAfter`, the ETA is current. After that window, the
/// ETA is stale and should be labeled that way anywhere it is shown externally.
struct ETAEstimate: Equatable, Identifiable, Sendable {
    let id: UUID
    let loadID: UUID
    let stopID: UUID?
    let estimatedArrivalAt: Date
    let generatedAt: Date
    let source: ETAEstimateSource
    let staleAfter: TimeInterval

    init(
        id: UUID = UUID(),
        loadID: UUID,
        stopID: UUID? = nil,
        estimatedArrivalAt: Date,
        generatedAt: Date,
        source: ETAEstimateSource,
        staleAfter: TimeInterval = 15 * 60
    ) throws {
        // P0 only publishes future-facing arrival estimates. Once arrival is in the
        // past, the load should be represented by an arrival/departure event instead.
        guard estimatedArrivalAt >= generatedAt else {
            throw ETAEstimateValidationError.estimateBeforeGeneratedAt
        }

        // A zero or negative freshness window would make every estimate instantly
        // stale or nonsensical, so callers must choose an explicit positive window.
        guard staleAfter > 0 else {
            throw ETAEstimateValidationError.nonPositiveFreshnessWindow
        }

        self.id = id
        self.loadID = loadID
        self.stopID = stopID
        self.estimatedArrivalAt = estimatedArrivalAt
        self.generatedAt = generatedAt
        self.source = source
        self.staleAfter = staleAfter
    }

    /// Classifies whether an ETA can still be described as current.
    ///
    /// The boundary is inclusive: an estimate generated at 8:00 with a 15-minute
    /// freshness window is still current at exactly 8:15, and becomes stale after
    /// that moment.
    func freshness(asOf date: Date) -> ETAFreshness {
        guard date >= generatedAt else { return .notYetGenerated }

        return date.timeIntervalSince(generatedAt) <= staleAfter
            ? .current
            : .stale
    }
}

/// The source tells the broker how to interpret the ETA.
///
/// - `manual`: the operator typed or adjusted the arrival time.
/// - `onDevice`: the app produced the estimate locally, for example from device
///   services or locally available trip information. It is still only an estimate.
enum ETAEstimateSource: String, Codable, Sendable {
    case manual
    case onDevice
}

enum ETAFreshness: String, Codable, Sendable {
    case notYetGenerated
    case current
    case stale
}

enum ETAEstimateValidationError: Error, Equatable, Sendable {
    case estimateBeforeGeneratedAt
    case nonPositiveFreshnessWindow
}

/// Destination coordinates for opening navigation in a native maps app.
///
/// These coordinates are the stop destination, not a driver location stream. Keeping
/// the domain object destination-only protects the P0 privacy promise: share ETA and
/// status, but do not expose precise current coordinates.
struct NavigationDestination: Equatable, Sendable {
    let name: String
    let latitude: Double
    let longitude: Double
}

/// A prepared handoff to the platform maps app.
///
/// The URL can launch driving directions, but HaulMate does not certify the route
/// for commercial trucks. Height, hazmat, weight, bridge, and road restriction rules
/// belong to a truck-routing product, not this P0 native Maps handoff.
struct NavigationHandoff: Equatable, Sendable {
    let destination: NavigationDestination
    let url: URL
    let mode: NavigationHandoffMode
    let isTruckSafeRouting: Bool
    let limitation: NavigationHandoffLimitation
}

enum NavigationHandoffMode: String, Codable, Sendable {
    case driving
}

enum NavigationHandoffLimitation: String, Codable, Sendable {
    case nativeMapsDrivingIsNotTruckSafeRouting
}

enum NavigationHandoffError: Error, Equatable, Sendable {
    case invalidCoordinate
    case invalidURL
}

/// Builds a native Apple Maps driving URL for the destination.
///
/// Coordinate validation follows the geographic ranges used by map providers:
/// latitude must be between -90 and 90 degrees, and longitude must be between
/// -180 and 180 degrees. The result is always marked as not truck-safe routing.
enum NativeMapsNavigationHandoff {
    static func makeHandoff(to destination: NavigationDestination) throws -> NavigationHandoff {
        guard destination.latitude >= -90,
              destination.latitude <= 90,
              destination.longitude >= -180,
              destination.longitude <= 180 else {
            throw NavigationHandoffError.invalidCoordinate
        }

        var components = URLComponents()
        components.scheme = "http"
        components.host = "maps.apple.com"
        components.path = "/"
        components.queryItems = [
            // Destination address in coordinate form. We intentionally do not add
            // an origin/current-location parameter to the shareable domain object.
            URLQueryItem(
                name: "daddr",
                value: "\(destination.latitude),\(destination.longitude)"
            ),
            // Human-readable label shown by Apple Maps when available.
            URLQueryItem(name: "q", value: destination.name),
            // `d` is Apple Maps' driving-directions flag, not a truck-routing mode.
            URLQueryItem(name: "dirflg", value: "d")
        ]

        guard let url = components.url else {
            throw NavigationHandoffError.invalidURL
        }

        return NavigationHandoff(
            destination: destination,
            url: url,
            mode: .driving,
            isTruckSafeRouting: false,
            limitation: .nativeMapsDrivingIsNotTruckSafeRouting
        )
    }
}
