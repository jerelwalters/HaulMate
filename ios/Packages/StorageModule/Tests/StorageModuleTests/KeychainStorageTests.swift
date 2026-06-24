//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
import Security
@testable import StorageModule

@MainActor
final class KeychainStorageTests: XCTestCase {
    func testReadReturnsNilForMissingKey() throws {
        let fixture = makeStorage()
        defer { fixture.removeStoredItems() }

        let value = try fixture.storage.read(StoredPilotPreference.self, for: "missing")

        XCTAssertNil(value)
    }

    func testSaveThenReadRoundTripsCodableValue() throws {
        let fixture = makeStorage()
        defer { fixture.removeStoredItems() }
        let preference = StoredPilotPreference(
            driverName: "Jerel",
            preferredFuelStopIDs: [
                UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
            ]
        )

        try fixture.storage.save(preference, for: "pilot-preference")

        XCTAssertEqual(
            try fixture.storage.read(StoredPilotPreference.self, for: "pilot-preference"),
            preference
        )
    }

    func testSaveReplacesExistingValueForKey() throws {
        let fixture = makeStorage()
        defer { fixture.removeStoredItems() }

        try fixture.storage.save(
            StoredPilotPreference(driverName: "First", preferredFuelStopIDs: []),
            for: "pilot-preference"
        )
        try fixture.storage.save(
            StoredPilotPreference(driverName: "Updated", preferredFuelStopIDs: []),
            for: "pilot-preference"
        )

        XCTAssertEqual(
            try fixture.storage.read(StoredPilotPreference.self, for: "pilot-preference"),
            StoredPilotPreference(driverName: "Updated", preferredFuelStopIDs: [])
        )
    }

    func testDeleteRemovesStoredValue() throws {
        let fixture = makeStorage()
        defer { fixture.removeStoredItems() }

        try fixture.storage.save(
            StoredPilotPreference(driverName: "Jerel", preferredFuelStopIDs: []),
            for: "pilot-preference"
        )

        try fixture.storage.delete("pilot-preference")

        XCTAssertNil(try fixture.storage.read(StoredPilotPreference.self, for: "pilot-preference"))
    }

    func testReadingStoredValueAsWrongTypeThrowsStorageError() throws {
        let fixture = makeStorage()
        defer { fixture.removeStoredItems() }

        try fixture.storage.save(
            StoredPilotPreference(driverName: "Jerel", preferredFuelStopIDs: []),
            for: "pilot-preference"
        )

        XCTAssertThrowsError(
            try fixture.storage.read(StoredRouteDraft.self, for: "pilot-preference")
        ) { error in
            XCTAssertEqual(
                error as? StorageError,
                .decodingFailed("pilot-preference")
            )
        }
    }

    private func makeStorage() -> KeychainStorageFixture {
        let service = "com.haulmate.storage-tests.\(UUID().uuidString)"

        return KeychainStorageFixture(
            service: service,
            storage: KeychainStorage(service: service)
        )
    }
}

private struct KeychainStorageFixture {
    let service: String
    let storage: KeychainStorage

    func removeStoredItems() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        SecItemDelete(query as CFDictionary)
    }
}

private struct StoredPilotPreference: Codable, Equatable {
    let driverName: String
    let preferredFuelStopIDs: [UUID]
}

private struct StoredRouteDraft: Codable, Equatable {
    let loadedMiles: Decimal
}
