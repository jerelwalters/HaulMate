//
//  Created by Jerel Walters on 6/30/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation
import StorageModule

actor HaulMateSecureSessionStore: AuthSessionStoring {
    private static let defaultBundleIdentifier = "com.jerelwalters.HaulMate"

    private let keychainService: String
    private let keychainAccessGroup: String?

    init(
        keychainService: String? = nil,
        keychainAccessGroup: String? = nil
    ) {
        let bundleID = Bundle.main.bundleIdentifier ?? Self.defaultBundleIdentifier

        self.keychainService = keychainService ?? "\(bundleID).auth-session"
        self.keychainAccessGroup = keychainAccessGroup
    }

    func readSession() async throws -> AuthSession? {
        try await MainActor.run {
            try keychainStorage()
                .read(AuthSession.self, for: HaulMateStorageKeys.authSession)
        }
    }

    func readSessionUserID() async throws -> UUID? {
        try await MainActor.run {
            try keychainStorage()
                .read(UUID.self, for: HaulMateStorageKeys.authSessionUserID)
        }
    }

    func saveSession(_ session: AuthSession) async throws {
        try await MainActor.run {
            let storage = keychainStorage()
            try storage.save(session, for: HaulMateStorageKeys.authSession)
            try storage.save(session.user.id, for: HaulMateStorageKeys.authSessionUserID)
        }
    }

    func deleteSession() async throws {
        try await MainActor.run {
            try keychainStorage()
                .delete(HaulMateStorageKeys.authSession)
        }
    }

    func deleteSessionUserID() async throws {
        try await MainActor.run {
            try keychainStorage()
                .delete(HaulMateStorageKeys.authSessionUserID)
        }
    }

    @MainActor
    private func keychainStorage() -> KeychainStorage {
        KeychainStorage(
            service: keychainService,
            accessGroup: keychainAccessGroup
        )
    }
}

actor HaulMateAccountScopedDataCleaner: AccountScopedDataClearing {
    func clearAccountScopedData() async throws {
        try await MainActor.run {
            try HaulMateLocalStorageRepository
                .fileBacked()
                .deleteAccountScopedData()
        }
    }
}

actor HaulMateBusinessProfileStore: BusinessProfileStoring {
    func readBusinessProfile() async throws -> BusinessProfileDraft? {
        try await MainActor.run {
            try HaulMateLocalStorageRepository
                .fileBacked()
                .readProfile()?
                .businessProfile
        }
    }

    func saveBusinessProfile(_ profile: BusinessProfileDraft) async throws {
        try await MainActor.run {
            let repository = try HaulMateLocalStorageRepository.fileBacked()
            var snapshot = try repository.readProfile() ?? ProfileSnapshot()
            snapshot.businessProfile = profile
            try repository.saveProfile(snapshot)
        }
    }
}
