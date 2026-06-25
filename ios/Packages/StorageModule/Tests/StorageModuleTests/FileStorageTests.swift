//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
@testable import StorageModule

@MainActor
final class FileStorageTests: XCTestCase {
    func testReadReturnsNilForMissingKey() throws {
        let fixture = try makeStorage()
        defer { fixture.removeStoredItems() }

        let value = try fixture.storage.read(StoredPilotPreference.self, for: "missing")

        XCTAssertNil(value)
    }

    func testSaveThenReadRoundTripsCodableValue() throws {
        let fixture = try makeStorage()
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
        let fixture = try makeStorage()
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
        let fixture = try makeStorage()
        defer { fixture.removeStoredItems() }

        try fixture.storage.save(
            StoredPilotPreference(driverName: "Jerel", preferredFuelStopIDs: []),
            for: "pilot-preference"
        )

        try fixture.storage.delete("pilot-preference")

        XCTAssertNil(try fixture.storage.read(StoredPilotPreference.self, for: "pilot-preference"))
    }

    func testReadingStoredValueAsWrongTypeThrowsStorageError() throws {
        let fixture = try makeStorage()
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

    func testKeysThatLookLikePathsRemainInsideStorageDirectory() throws {
        let fixture = try makeStorage()
        defer { fixture.removeStoredItems() }

        try fixture.storage.save(
            StoredPilotPreference(driverName: "Jerel", preferredFuelStopIDs: []),
            for: "workflow/active"
        )

        let storedFiles = try FileManager.default.contentsOfDirectory(
            at: fixture.directoryURL,
            includingPropertiesForKeys: nil
        )

        XCTAssertEqual(storedFiles.count, 1)
        XCTAssertEqual(storedFiles[0].deletingPathExtension().lastPathComponent, "d29ya2Zsb3cvYWN0aXZl")
        XCTAssertEqual(storedFiles[0].pathExtension, "json")
    }

    private func makeStorage() throws -> FileStorageFixture {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.haulmate.storage-tests.\(UUID().uuidString)", isDirectory: true)

        return try FileStorageFixture(
            directoryURL: directoryURL,
            storage: FileStorage(
                directoryURL: directoryURL,
                fileProtection: .completeUntilFirstUserAuthentication
            )
        )
    }
}

private struct FileStorageFixture {
    let directoryURL: URL
    let storage: FileStorage

    func removeStoredItems() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

private struct StoredPilotPreference: Codable, Equatable {
    let driverName: String
    let preferredFuelStopIDs: [UUID]
}

private struct StoredRouteDraft: Codable, Equatable {
    let loadedMiles: Decimal
}
