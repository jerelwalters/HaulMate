//
//  Created by Jerel Walters on 6/21/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

struct Load: Equatable, Identifiable, Sendable {
    let id: UUID
    let referenceNumber: String?
    let status: LoadStatus
    let stops: [LoadStop]
    let tripEvents: [TripEvent]

    init(
        id: UUID = UUID(),
        referenceNumber: String? = nil,
        status: LoadStatus = .evaluating,
        stops: [LoadStop] = [],
        tripEvents: [TripEvent] = []
    ) {
        self.id = id
        self.referenceNumber = referenceNumber
        self.status = status
        self.stops = stops
        self.tripEvents = tripEvents
    }

    func transitioning(
        to nextStatus: LoadStatus,
        eventID: UUID = UUID(),
        occurredAt: Date,
        timezoneIdentifier: String,
        location: TripEventLocation = .unavailable,
        note: String? = nil
    ) throws -> Load {
        guard status.canTransition(to: nextStatus) else {
            throw LoadStateMachineError.invalidTransition(
                from: status,
                to: nextStatus
            )
        }

        let event = TripEvent(
            id: eventID,
            loadID: id,
            stopID: nil,
            kind: .statusChanged(from: status, to: nextStatus),
            status: nextStatus,
            occurredAt: occurredAt,
            timezoneIdentifier: timezoneIdentifier,
            location: location,
            note: note
        )

        return Load(
            id: id,
            referenceNumber: referenceNumber,
            status: nextStatus,
            stops: stops,
            tripEvents: tripEvents + [event]
        )
    }

    func transitioning(
        to nextStatus: LoadStatus,
        eventID: UUID = UUID(),
        capture: TripEventCapture,
        note: String? = nil
    ) throws -> Load {
        try transitioning(
            to: nextStatus,
            eventID: eventID,
            occurredAt: capture.occurredAt,
            timezoneIdentifier: capture.timezoneIdentifier,
            location: capture.location,
            note: note
        )
    }

    func recordingArrival(
        at stopID: UUID,
        eventID: UUID = UUID(),
        occurredAt: Date,
        timezoneIdentifier: String,
        location: TripEventLocation = .unavailable,
        note: String? = nil
    ) throws -> Load {
        try recordingStopEvent(
            .arrived,
            stopID: stopID,
            eventID: eventID,
            occurredAt: occurredAt,
            timezoneIdentifier: timezoneIdentifier,
            location: location,
            note: note
        )
    }

    func recordingArrival(
        at stopID: UUID,
        eventID: UUID = UUID(),
        capture: TripEventCapture,
        note: String? = nil
    ) throws -> Load {
        try recordingArrival(
            at: stopID,
            eventID: eventID,
            occurredAt: capture.occurredAt,
            timezoneIdentifier: capture.timezoneIdentifier,
            location: capture.location,
            note: note
        )
    }

    func recordingDeparture(
        from stopID: UUID,
        eventID: UUID = UUID(),
        occurredAt: Date,
        timezoneIdentifier: String,
        location: TripEventLocation = .unavailable,
        note: String? = nil
    ) throws -> Load {
        try recordingStopEvent(
            .departed,
            stopID: stopID,
            eventID: eventID,
            occurredAt: occurredAt,
            timezoneIdentifier: timezoneIdentifier,
            location: location,
            note: note
        )
    }

    func recordingDeparture(
        from stopID: UUID,
        eventID: UUID = UUID(),
        capture: TripEventCapture,
        note: String? = nil
    ) throws -> Load {
        try recordingDeparture(
            from: stopID,
            eventID: eventID,
            occurredAt: capture.occurredAt,
            timezoneIdentifier: capture.timezoneIdentifier,
            location: capture.location,
            note: note
        )
    }

    func correcting(
        eventID originalEventID: UUID,
        correctionID: UUID = UUID(),
        occurredAt: Date,
        timezoneIdentifier: String,
        reason: String
    ) throws -> Load {
        guard let originalEvent = tripEvents.first(where: { $0.id == originalEventID }) else {
            throw LoadStateMachineError.missingOriginalEvent(originalEventID)
        }

        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty else {
            throw LoadStateMachineError.emptyCorrectionReason
        }

        // Corrections are audit-only here. Re-applying corrected state belongs
        // in the workflow/repository layer that owns conflict and review policy.
        let correction = TripEvent(
            id: correctionID,
            loadID: id,
            stopID: originalEvent.stopID,
            kind: .corrected(originalEventID: originalEventID),
            status: status,
            occurredAt: occurredAt,
            timezoneIdentifier: timezoneIdentifier,
            location: .manual,
            note: trimmedReason
        )

        return Load(
            id: id,
            referenceNumber: referenceNumber,
            status: status,
            stops: stops,
            tripEvents: tripEvents + [correction]
        )
    }

    private func recordingStopEvent(
        _ kind: TripEventKind,
        stopID: UUID,
        eventID: UUID,
        occurredAt: Date,
        timezoneIdentifier: String,
        location: TripEventLocation,
        note: String?
    ) throws -> Load {
        guard stops.contains(where: { $0.id == stopID }) else {
            throw LoadStateMachineError.unknownStop(stopID)
        }

        let event = TripEvent(
            id: eventID,
            loadID: id,
            stopID: stopID,
            kind: kind,
            status: status,
            occurredAt: occurredAt,
            timezoneIdentifier: timezoneIdentifier,
            location: location,
            note: note
        )

        return Load(
            id: id,
            referenceNumber: referenceNumber,
            status: status,
            stops: stops,
            tripEvents: tripEvents + [event]
        )
    }
}

enum LoadStatus: String, CaseIterable, Codable, Sendable {
    case evaluating
    case accepted
    case enRouteToPickup
    case atPickup
    case inTransit
    case atDelivery
    case delivered
    case invoiced
    case paid
    case cancelled
    case disputed

    var allowedNextStatuses: [LoadStatus] {
        switch self {
        case .evaluating:
            return [.accepted, .cancelled]
        case .accepted:
            return [.enRouteToPickup, .cancelled, .disputed]
        case .enRouteToPickup:
            return [.atPickup, .cancelled, .disputed]
        case .atPickup:
            return [.inTransit, .cancelled, .disputed]
        case .inTransit:
            return [.atDelivery, .cancelled, .disputed]
        case .atDelivery:
            return [.delivered, .cancelled, .disputed]
        case .delivered:
            return [.invoiced, .disputed]
        case .invoiced:
            return [.paid, .disputed]
        case .paid, .cancelled, .disputed:
            return []
        }
    }

    var isTerminal: Bool {
        allowedNextStatuses.isEmpty
    }

    func canTransition(to nextStatus: LoadStatus) -> Bool {
        allowedNextStatuses.contains(nextStatus)
    }
}

struct LoadStop: Equatable, Identifiable, Sendable {
    let id: UUID
    let kind: LoadStopKind
    let sequence: Int
    let facilityName: String
    let appointmentWindow: AppointmentWindow?

    init(
        id: UUID = UUID(),
        kind: LoadStopKind,
        sequence: Int,
        facilityName: String,
        appointmentWindow: AppointmentWindow? = nil
    ) {
        self.id = id
        self.kind = kind
        self.sequence = sequence
        self.facilityName = facilityName
        self.appointmentWindow = appointmentWindow
    }
}

enum LoadStopKind: String, Codable, Sendable {
    case pickup
    case delivery
    case extra
}

struct AppointmentWindow: Equatable, Sendable {
    let startsAt: Date
    let endsAt: Date
    let timezoneIdentifier: String
}

struct TripEvent: Equatable, Identifiable, Sendable {
    let id: UUID
    let loadID: UUID
    let stopID: UUID?
    let kind: TripEventKind
    let status: LoadStatus
    let occurredAt: Date
    let timezoneIdentifier: String
    let location: TripEventLocation
    let note: String?
}

enum TripEventKind: Equatable, Sendable {
    case statusChanged(from: LoadStatus, to: LoadStatus)
    case arrived
    case departed
    case corrected(originalEventID: UUID)
}

struct TripEventCapture: Equatable, Sendable {
    let occurredAt: Date
    let timezoneIdentifier: String
    let location: TripEventLocation

    // Date is an absolute instant; the timezone preserves how the device
    // should display and audit the event later.
    init(
        occurredAt: Date,
        timezoneIdentifier: String,
        location: TripEventLocation = .unavailable
    ) {
        self.occurredAt = occurredAt
        self.timezoneIdentifier = timezoneIdentifier
        self.location = location
    }

    init(
        occurredAt: Date,
        timeZone: TimeZone,
        location: TripEventLocation = .unavailable
    ) {
        self.init(
            occurredAt: occurredAt,
            timezoneIdentifier: timeZone.identifier,
            location: location
        )
    }
}

struct TripEventLocation: Equatable, Sendable {
    let source: TripEventLocationSource
    let latitude: Double?
    let longitude: Double?
    let horizontalAccuracyMeters: Double?

    var isDeviceVerified: Bool {
        source == .deviceVerified
            && latitude != nil
            && longitude != nil
            && horizontalAccuracyMeters != nil
    }

    var hasDeviceCoordinates: Bool {
        latitude != nil
            && longitude != nil
            && horizontalAccuracyMeters != nil
    }

    var isManualOrUnverified: Bool {
        !isDeviceVerified
    }

    static func capturedDeviceLocation(
        latitude: Double,
        longitude: Double,
        horizontalAccuracyMeters: Double,
        verifiedAccuracyThresholdMeters: Double = 50
    ) -> TripEventLocation {
        if horizontalAccuracyMeters <= verifiedAccuracyThresholdMeters {
            return .deviceVerified(
                latitude: latitude,
                longitude: longitude,
                horizontalAccuracyMeters: horizontalAccuracyMeters
            )
        }

        return .poorAccuracy(
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracyMeters: horizontalAccuracyMeters
        )
    }

    static func deviceVerified(
        latitude: Double,
        longitude: Double,
        horizontalAccuracyMeters: Double
    ) -> TripEventLocation {
        TripEventLocation(
            source: .deviceVerified,
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracyMeters: horizontalAccuracyMeters
        )
    }

    static func poorAccuracy(
        latitude: Double,
        longitude: Double,
        horizontalAccuracyMeters: Double
    ) -> TripEventLocation {
        TripEventLocation(
            source: .poorAccuracy,
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracyMeters: horizontalAccuracyMeters
        )
    }

    static let unavailable = TripEventLocation(source: .unavailable)
    static let permissionDenied = TripEventLocation(source: .permissionDenied)
    static let manual = TripEventLocation(source: .manual)

    private init(
        source: TripEventLocationSource,
        latitude: Double? = nil,
        longitude: Double? = nil,
        horizontalAccuracyMeters: Double? = nil
    ) {
        self.source = source
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
    }
}

enum TripEventLocationSource: String, Codable, Sendable {
    case deviceVerified
    case poorAccuracy
    case unavailable
    case permissionDenied
    case manual
}

enum LoadStateMachineError: Error, Equatable, Sendable {
    case invalidTransition(from: LoadStatus, to: LoadStatus)
    case unknownStop(UUID)
    case missingOriginalEvent(UUID)
    case emptyCorrectionReason
}
