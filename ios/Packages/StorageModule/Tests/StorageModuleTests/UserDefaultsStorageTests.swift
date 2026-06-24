//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
@testable import StorageModule

@MainActor
final class UserDefaultsStorageTests: XCTestCase {
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

    private func makeStorage() -> UserDefaultsStorageFixture {
        let suiteName = "com.haulmate.storage-tests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        return UserDefaultsStorageFixture(
            suiteName: suiteName,
            userDefaults: userDefaults,
            storage: UserDefaultsStorage(userDefaults: userDefaults)
        )
    }
}

private struct UserDefaultsStorageFixture {
    let suiteName: String
    let userDefaults: UserDefaults
    let storage: UserDefaultsStorage

    func removeStoredItems() {
        userDefaults.removePersistentDomain(forName: suiteName)
    }
}

private struct StoredPilotPreference: Codable, Equatable {
    let driverName: String
    let preferredFuelStopIDs: [UUID]
}

private struct StoredRouteDraft: Codable, Equatable {
    let loadedMiles: Decimal
}
