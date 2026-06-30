//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation
import StorageModule

@MainActor
final class HaulMateLocalStorageRepository {
    private static let fileDirectoryName = "HaulMateLocalStore"
    private static let userDefaultsKeyPrefix = "HaulMate.local-storage."
    private static var keychainService: String {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.haulmate.HaulMate"

        return "\(bundleID).local-storage"
    }

    private let storage: any Storage

    init(storage: any Storage) {
        self.storage = storage
    }

    init(
        storageType: StorageType = .fileStorage,
        userDefaults: UserDefaults = .standard,
        fileDirectoryURL: URL? = nil,
        keychainService: String? = nil
    ) throws {
        // HaulMate local state defaults to protected files; Keychain stays reserved for secrets.
        self.storage = try storageType.makeStorage(
            userDefaults: userDefaults,
            userDefaultsKeyPrefix: Self.userDefaultsKeyPrefix,
            fileDirectoryURL: fileDirectoryURL,
            fileDirectoryName: Self.fileDirectoryName,
            fileProtection: .completeUntilFirstUserAuthentication,
            keychainService: keychainService ?? Self.keychainService
        )
    }

    static func fileBacked() throws -> HaulMateLocalStorageRepository {
        try HaulMateLocalStorageRepository(storageType: .fileStorage)
    }

    func readActiveWorkflow() throws -> ActiveWorkflowSnapshot? {
        try storage
            .read(StoredActiveWorkflow.self, for: HaulMateStorageKeys.activeWorkflow)?
            .snapshot
    }

    func saveActiveWorkflow(_ snapshot: ActiveWorkflowSnapshot) throws {
        try storage.save(
            StoredActiveWorkflow(snapshot: snapshot),
            for: HaulMateStorageKeys.activeWorkflow
        )
    }

    func deleteActiveWorkflow() throws {
        try storage.delete(HaulMateStorageKeys.activeWorkflow)
    }

    func readProfile() throws -> ProfileSnapshot? {
        guard let storedProfile = try storage.read(StoredProfile.self, for: HaulMateStorageKeys.profile) else {
            return nil
        }

        let snapshot = storedProfile.snapshot

        if storedProfile.requiresMigration {
            try saveProfile(snapshot)
        }

        return snapshot
    }

    func saveProfile(_ snapshot: ProfileSnapshot) throws {
        try storage.save(
            StoredProfile.current(from: snapshot),
            for: HaulMateStorageKeys.profile
        )
    }

    func deleteProfile() throws {
        try storage.delete(HaulMateStorageKeys.profile)
    }

    func readRecentDocuments() throws -> RecentDocumentsSnapshot? {
        try storage
            .read(StoredRecentDocuments.self, for: HaulMateStorageKeys.recentDocuments)?
            .snapshot
    }

    func saveRecentDocuments(_ snapshot: RecentDocumentsSnapshot) throws {
        try storage.save(
            StoredRecentDocuments(snapshot: snapshot),
            for: HaulMateStorageKeys.recentDocuments
        )
    }

    func deleteRecentDocuments() throws {
        try storage.delete(HaulMateStorageKeys.recentDocuments)
    }

    func readSyncMetadata() throws -> SyncMetadataSnapshot? {
        try storage
            .read(StoredSyncMetadata.self, for: HaulMateStorageKeys.syncMetadata)?
            .snapshot
    }

    func saveSyncMetadata(_ snapshot: SyncMetadataSnapshot) throws {
        try storage.save(
            StoredSyncMetadata(snapshot: snapshot),
            for: HaulMateStorageKeys.syncMetadata
        )
    }

    func deleteSyncMetadata() throws {
        try storage.delete(HaulMateStorageKeys.syncMetadata)
    }

    func deleteAccountScopedData() throws {
        try deleteActiveWorkflow()
        try deleteProfile()
        try deleteRecentDocuments()
        try deleteSyncMetadata()
    }
}
