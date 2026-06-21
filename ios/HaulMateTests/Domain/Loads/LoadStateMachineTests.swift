//
//  Created by Jerel Walters on 6/21/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
@testable import HaulMate

final class LoadStateMachineTests: XCTestCase {
    func testForwardTripSequenceAppendsStatusEvents() throws {
        var load = Load(id: IDs.load)
        let statuses: [LoadStatus] = [
            .accepted,
            .enRouteToPickup,
            .atPickup,
            .inTransit,
            .atDelivery,
            .delivered,
            .invoiced,
            .paid
        ]

        for (index, status) in statuses.enumerated() {
            load = try load.transitioning(
                to: status,
                eventID: IDs.event(index),
                occurredAt: Dates.event(index),
                timezoneIdentifier: Constants.timezoneIdentifier,
                location: .manual
            )
        }

        XCTAssertEqual(load.status, .paid)
        XCTAssertEqual(load.tripEvents.count, statuses.count)
        XCTAssertTrue(load.status.isTerminal)

        XCTAssertEqual(
            load.tripEvents.map(\.kind),
            [
                .statusChanged(from: .evaluating, to: .accepted),
                .statusChanged(from: .accepted, to: .enRouteToPickup),
                .statusChanged(from: .enRouteToPickup, to: .atPickup),
                .statusChanged(from: .atPickup, to: .inTransit),
                .statusChanged(from: .inTransit, to: .atDelivery),
                .statusChanged(from: .atDelivery, to: .delivered),
                .statusChanged(from: .delivered, to: .invoiced),
                .statusChanged(from: .invoiced, to: .paid)
            ]
        )
        XCTAssertEqual(load.tripEvents.map(\.loadID), Array(repeating: IDs.load, count: statuses.count))
        XCTAssertEqual(load.tripEvents.map(\.status), statuses)
    }

    func testInvalidTransitionThrowsAndLeavesOriginalLoadUnchanged() {
        let load = Load(id: IDs.load)

        XCTAssertThrowsError(
            try load.transitioning(
                to: .delivered,
                eventID: IDs.event(0),
                occurredAt: Dates.event(0),
                timezoneIdentifier: Constants.timezoneIdentifier
            )
        ) { error in
            XCTAssertEqual(
                error as? LoadStateMachineError,
                .invalidTransition(from: .evaluating, to: .delivered)
            )
        }

        XCTAssertEqual(load.status, .evaluating)
        XCTAssertTrue(load.tripEvents.isEmpty)
    }

    func testCancelledStatusIsTerminal() throws {
        let accepted = try Load(id: IDs.load).transitioning(
            to: .accepted,
            eventID: IDs.event(0),
            occurredAt: Dates.event(0),
            timezoneIdentifier: Constants.timezoneIdentifier
        )

        let cancelled = try accepted.transitioning(
            to: .cancelled,
            eventID: IDs.event(1),
            occurredAt: Dates.event(1),
            timezoneIdentifier: Constants.timezoneIdentifier
        )

        XCTAssertEqual(cancelled.status, .cancelled)
        XCTAssertTrue(cancelled.status.isTerminal)

        XCTAssertThrowsError(
            try cancelled.transitioning(
                to: .enRouteToPickup,
                eventID: IDs.event(2),
                occurredAt: Dates.event(2),
                timezoneIdentifier: Constants.timezoneIdentifier
            )
        ) { error in
            XCTAssertEqual(
                error as? LoadStateMachineError,
                .invalidTransition(from: .cancelled, to: .enRouteToPickup)
            )
        }
    }

    func testDisputedStatusIsTerminal() throws {
        var load = Load(id: IDs.load)

        for (index, status) in [
            LoadStatus.accepted,
            .enRouteToPickup,
            .atPickup,
            .inTransit,
            .atDelivery,
            .delivered
        ].enumerated() {
            load = try load.transitioning(
                to: status,
                eventID: IDs.event(index),
                occurredAt: Dates.event(index),
                timezoneIdentifier: Constants.timezoneIdentifier
            )
        }

        let disputed = try load.transitioning(
            to: .disputed,
            eventID: IDs.event(6),
            occurredAt: Dates.event(6),
            timezoneIdentifier: Constants.timezoneIdentifier
        )

        XCTAssertEqual(disputed.status, .disputed)
        XCTAssertTrue(disputed.status.isTerminal)

        XCTAssertThrowsError(
            try disputed.transitioning(
                to: .paid,
                eventID: IDs.event(7),
                occurredAt: Dates.event(7),
                timezoneIdentifier: Constants.timezoneIdentifier
            )
        ) { error in
            XCTAssertEqual(
                error as? LoadStateMachineError,
                .invalidTransition(from: .disputed, to: .paid)
            )
        }
    }

    func testArrivalAndDepartureEventsDoNotChangeLoadStatus() throws {
        let stop = LoadStop(
            id: IDs.pickupStop,
            kind: .pickup,
            sequence: 0,
            facilityName: "Detroit Pickup"
        )
        let load = Load(id: IDs.load, status: .atPickup, stops: [stop])

        let arrived = try load.recordingArrival(
            at: IDs.pickupStop,
            eventID: IDs.event(0),
            occurredAt: Dates.event(0),
            timezoneIdentifier: Constants.timezoneIdentifier,
            location: .deviceVerified(
                latitude: 42.3314,
                longitude: -83.0458,
                horizontalAccuracyMeters: 12
            )
        )
        let departed = try arrived.recordingDeparture(
            from: IDs.pickupStop,
            eventID: IDs.event(1),
            occurredAt: Dates.event(1),
            timezoneIdentifier: Constants.timezoneIdentifier,
            location: .poorAccuracy(
                latitude: 42.3314,
                longitude: -83.0458,
                horizontalAccuracyMeters: 120
            )
        )

        XCTAssertEqual(departed.status, .atPickup)
        XCTAssertEqual(departed.tripEvents.map(\.kind), [.arrived, .departed])
        XCTAssertEqual(departed.tripEvents.map(\.stopID), [IDs.pickupStop, IDs.pickupStop])
        XCTAssertEqual(departed.tripEvents[0].location?.isDeviceVerified, true)
        XCTAssertEqual(departed.tripEvents[1].location?.isDeviceVerified, false)
    }

    func testStopEventRequiresKnownStop() {
        let load = Load(id: IDs.load)

        XCTAssertThrowsError(
            try load.recordingArrival(
                at: IDs.pickupStop,
                eventID: IDs.event(0),
                occurredAt: Dates.event(0),
                timezoneIdentifier: Constants.timezoneIdentifier
            )
        ) { error in
            XCTAssertEqual(
                error as? LoadStateMachineError,
                .unknownStop(IDs.pickupStop)
            )
        }
    }

    func testCorrectionAppendsAuditEventWithoutReplacingOriginalEvent() throws {
        let accepted = try Load(id: IDs.load).transitioning(
            to: .accepted,
            eventID: IDs.event(0),
            occurredAt: Dates.event(0),
            timezoneIdentifier: Constants.timezoneIdentifier,
            location: .permissionDenied
        )
        let originalEvent = try XCTUnwrap(accepted.tripEvents.first)

        let corrected = try accepted.correcting(
            eventID: IDs.event(0),
            correctionID: IDs.event(1),
            occurredAt: Dates.event(1),
            timezoneIdentifier: Constants.timezoneIdentifier,
            reason: "  Driver tapped accepted before broker confirmed.  "
        )

        XCTAssertEqual(corrected.tripEvents.first, originalEvent)
        XCTAssertEqual(corrected.tripEvents.count, 2)
        XCTAssertEqual(
            corrected.tripEvents[1].kind,
            .corrected(originalEventID: IDs.event(0))
        )
        XCTAssertEqual(
            corrected.tripEvents[1].note,
            "Driver tapped accepted before broker confirmed."
        )
        XCTAssertEqual(corrected.status, .accepted)
    }

    func testCorrectionRequiresExistingEventAndReason() throws {
        let accepted = try Load(id: IDs.load).transitioning(
            to: .accepted,
            eventID: IDs.event(0),
            occurredAt: Dates.event(0),
            timezoneIdentifier: Constants.timezoneIdentifier
        )

        XCTAssertThrowsError(
            try accepted.correcting(
                eventID: IDs.event(99),
                correctionID: IDs.event(1),
                occurredAt: Dates.event(1),
                timezoneIdentifier: Constants.timezoneIdentifier,
                reason: "Wrong event"
            )
        ) { error in
            XCTAssertEqual(
                error as? LoadStateMachineError,
                .missingOriginalEvent(IDs.event(99))
            )
        }

        XCTAssertThrowsError(
            try accepted.correcting(
                eventID: IDs.event(0),
                correctionID: IDs.event(1),
                occurredAt: Dates.event(1),
                timezoneIdentifier: Constants.timezoneIdentifier,
                reason: "   "
            )
        ) { error in
            XCTAssertEqual(error as? LoadStateMachineError, .emptyCorrectionReason)
        }
    }
}

private enum Constants {
    static let timezoneIdentifier = "America/Detroit"
}

private enum Dates {
    static func event(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 1_782_000_000 + TimeInterval(offset))
    }
}

private enum IDs {
    static let load = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let pickupStop = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    static func event(_ index: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", index + 10))")!
    }
}
