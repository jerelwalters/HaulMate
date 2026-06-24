//
//  Created by Jerel Walters on 6/22/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
@testable import HaulMate

final class ETAEstimationTests: XCTestCase {
    func testNaturalLanguageETAEstimateFreshnessBreakdownMatchesFormula() throws {
        let generatedAt = time(minutes: 8 * 60)
        let estimate = try ETAEstimate(
            id: IDs.estimate,
            loadID: IDs.load,
            stopID: IDs.deliveryStop,
            estimatedArrivalAt: time(minutes: (9 * 60) + 30),
            generatedAt: generatedAt,
            source: .manual,
            staleAfter: 15 * 60
        )

        XCTAssertEqual(estimate.source, .manual)
        XCTAssertEqual(estimate.estimatedArrivalAt, time(minutes: (9 * 60) + 30))
        XCTAssertEqual(estimate.generatedAt, time(minutes: 8 * 60))

        // Driver says at 8:00, "I expect to arrive at 9:30." The ETA is current
        // through the 15-minute freshness window, then it needs a stale label.
        XCTAssertEqual(estimate.freshness(asOf: generatedAt.addingTimeInterval(-1)), .notYetGenerated)
        XCTAssertEqual(estimate.freshness(asOf: generatedAt.addingTimeInterval((15 * 60) - 1)), .current)
        XCTAssertEqual(estimate.freshness(asOf: generatedAt.addingTimeInterval(15 * 60)), .current)
        XCTAssertEqual(estimate.freshness(asOf: generatedAt.addingTimeInterval((15 * 60) + 1)), .stale)
    }

    func testManualEstimateStoresSourceAndFreshness() throws {
        let generatedAt = time(minutes: 60)
        let estimate = try ETAEstimate(
            id: IDs.estimate,
            loadID: IDs.load,
            stopID: IDs.deliveryStop,
            estimatedArrivalAt: time(minutes: 180),
            generatedAt: generatedAt,
            source: .manual,
            staleAfter: 15 * 60
        )

        XCTAssertEqual(estimate.id, IDs.estimate)
        XCTAssertEqual(estimate.loadID, IDs.load)
        XCTAssertEqual(estimate.stopID, IDs.deliveryStop)
        XCTAssertEqual(estimate.source, .manual)
        XCTAssertEqual(estimate.freshness(asOf: generatedAt.addingTimeInterval(14 * 60)), .current)
        XCTAssertEqual(estimate.freshness(asOf: generatedAt.addingTimeInterval(16 * 60)), .stale)
    }

    func testOnDeviceEstimateCanRepresentNotYetGeneratedAndCurrentStates() throws {
        let generatedAt = time(minutes: 30)
        let estimate = try ETAEstimate(
            id: IDs.estimate,
            loadID: IDs.load,
            estimatedArrivalAt: time(minutes: 90),
            generatedAt: generatedAt,
            source: .onDevice,
            staleAfter: 10 * 60
        )

        XCTAssertEqual(estimate.source, .onDevice)
        XCTAssertNil(estimate.stopID)
        XCTAssertEqual(estimate.freshness(asOf: generatedAt.addingTimeInterval(-60)), .notYetGenerated)
        XCTAssertEqual(estimate.freshness(asOf: generatedAt.addingTimeInterval(10 * 60)), .current)
    }

    func testFreshnessUsesGeneratedTimeNotHowFarAwayArrivalIs() throws {
        let generatedAt = time(minutes: 30)
        let estimate = try ETAEstimate(
            id: IDs.estimate,
            loadID: IDs.load,
            estimatedArrivalAt: generatedAt.addingTimeInterval(4 * 60 * 60),
            generatedAt: generatedAt,
            source: .onDevice,
            staleAfter: 10 * 60
        )

        XCTAssertEqual(estimate.estimatedArrivalAt, generatedAt.addingTimeInterval(4 * 60 * 60))
        XCTAssertEqual(estimate.freshness(asOf: generatedAt.addingTimeInterval(9 * 60)), .current)
        XCTAssertEqual(estimate.freshness(asOf: generatedAt.addingTimeInterval(11 * 60)), .stale)
    }

    func testETAEstimateValidationRejectsPastEstimateAndInvalidFreshness() {
        XCTAssertThrowsError(
            try ETAEstimate(
                loadID: IDs.load,
                estimatedArrivalAt: time(minutes: 29),
                generatedAt: time(minutes: 30),
                source: .manual
            )
        ) { error in
            XCTAssertEqual(error as? ETAEstimateValidationError, .estimateBeforeGeneratedAt)
        }

        XCTAssertThrowsError(
            try ETAEstimate(
                loadID: IDs.load,
                estimatedArrivalAt: time(minutes: 45),
                generatedAt: time(minutes: 30),
                source: .manual,
                staleAfter: 0
            )
        ) { error in
            XCTAssertEqual(error as? ETAEstimateValidationError, .nonPositiveFreshnessWindow)
        }
    }

    func testNativeMapsHandoffBuildsDrivingURLAndMarksNotTruckSafe() throws {
        let handoff = try NativeMapsNavigationHandoff.makeHandoff(
            to: NavigationDestination(
                name: "Detroit Receiver",
                latitude: 42.3314,
                longitude: -83.0458
            )
        )
        let components = try XCTUnwrap(URLComponents(url: handoff.url, resolvingAgainstBaseURL: false))
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            }
        )

        XCTAssertEqual(components.scheme, "http")
        XCTAssertEqual(components.host, "maps.apple.com")
        XCTAssertEqual(query["daddr"], "42.3314,-83.0458")
        XCTAssertEqual(query["q"], "Detroit Receiver")
        XCTAssertEqual(query["dirflg"], "d")
        XCTAssertEqual(handoff.mode, .driving)
        XCTAssertFalse(handoff.isTruckSafeRouting)
        XCTAssertEqual(handoff.limitation, .nativeMapsDrivingIsNotTruckSafeRouting)
    }

    func testNativeMapsHandoffUsesDestinationOnlyAndDoesNotClaimTruckRouting() throws {
        let handoff = try NativeMapsNavigationHandoff.makeHandoff(
            to: NavigationDestination(
                name: "Chicago Receiver",
                latitude: 41.8781,
                longitude: -87.6298
            )
        )
        let query = try queryItems(from: handoff.url)

        XCTAssertEqual(Set(query.keys), ["daddr", "q", "dirflg"])
        XCTAssertEqual(query["daddr"], "41.8781,-87.6298")
        XCTAssertNil(query["saddr"])
        XCTAssertFalse(handoff.isTruckSafeRouting)
        XCTAssertEqual(handoff.limitation, .nativeMapsDrivingIsNotTruckSafeRouting)
    }

    func testCoordinateBoundaryValuesAreAccepted() throws {
        let northeastEdge = try NativeMapsNavigationHandoff.makeHandoff(
            to: NavigationDestination(
                name: "Northeast coordinate boundary",
                latitude: 90,
                longitude: 180
            )
        )
        let southwestEdge = try NativeMapsNavigationHandoff.makeHandoff(
            to: NavigationDestination(
                name: "Southwest coordinate boundary",
                latitude: -90,
                longitude: -180
            )
        )

        XCTAssertEqual(try queryItems(from: northeastEdge.url)["daddr"], "90.0,180.0")
        XCTAssertEqual(try queryItems(from: southwestEdge.url)["daddr"], "-90.0,-180.0")
    }

    func testNavigationHandoffRejectsInvalidCoordinates() {
        XCTAssertThrowsError(
            try NativeMapsNavigationHandoff.makeHandoff(
                to: NavigationDestination(
                    name: "Bad latitude",
                    latitude: 91,
                    longitude: -83.0458
                )
            )
        ) { error in
            XCTAssertEqual(error as? NavigationHandoffError, .invalidCoordinate)
        }

        XCTAssertThrowsError(
            try NativeMapsNavigationHandoff.makeHandoff(
                to: NavigationDestination(
                    name: "Bad longitude",
                    latitude: 42.3314,
                    longitude: -181
                )
            )
        ) { error in
            XCTAssertEqual(error as? NavigationHandoffError, .invalidCoordinate)
        }
    }
}

private enum IDs {
    static let estimate = UUID(uuidString: "00000000-0000-0000-0000-000000000401")!
    static let load = UUID(uuidString: "00000000-0000-0000-0000-000000000402")!
    static let deliveryStop = UUID(uuidString: "00000000-0000-0000-0000-000000000403")!
}

private func queryItems(from url: URL) throws -> [String: String] {
    let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
    return Dictionary(
        uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        }
    )
}

private func time(minutes: Int) -> Date {
    Date(timeIntervalSince1970: TimeInterval(minutes * 60))
}
