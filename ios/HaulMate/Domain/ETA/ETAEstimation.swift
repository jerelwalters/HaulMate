//
//  Created by Jerel Walters on 6/22/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

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
        guard estimatedArrivalAt >= generatedAt else {
            throw ETAEstimateValidationError.estimateBeforeGeneratedAt
        }

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

    func freshness(asOf date: Date) -> ETAFreshness {
        guard date >= generatedAt else { return .notYetGenerated }

        return date.timeIntervalSince(generatedAt) <= staleAfter
            ? .current
            : .stale
    }
}

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

struct NavigationDestination: Equatable, Sendable {
    let name: String
    let latitude: Double
    let longitude: Double
}

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
            URLQueryItem(
                name: "daddr",
                value: "\(destination.latitude),\(destination.longitude)"
            ),
            URLQueryItem(name: "q", value: destination.name),
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
