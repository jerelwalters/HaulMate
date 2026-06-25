//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
@testable import StorageModule

@MainActor
final class StorageTypeTests: XCTestCase {
    func testUserDefaultsSelectionCreatesUserDefaultsStorage() throws {
        let suiteName = "com.haulmate.storage-type-tests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let storage = try StorageType.userDefaults.makeStorage(
            userDefaults: userDefaults,
            userDefaultsKeyPrefix: "test."
        )

        XCTAssertTrue(storage is UserDefaultsStorage)
    }

    func testFileStorageSelectionCreatesFileStorage() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.haulmate.storage-type-tests.\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let storage = try StorageType.fileStorage.makeStorage(
            fileDirectoryURL: directoryURL,
            fileProtection: .completeUntilFirstUserAuthentication
        )

        XCTAssertTrue(storage is FileStorage)
    }

    func testSecureSelectionCreatesKeychainStorage() throws {
        let storage = try StorageType.secure.makeStorage(
            keychainService: "com.haulmate.storage-type-tests.\(UUID().uuidString)"
        )

        XCTAssertTrue(storage is KeychainStorage)
    }
}
