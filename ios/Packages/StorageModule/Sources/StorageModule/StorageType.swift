//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

public enum StorageType: Equatable, Sendable {
    case userDefaults
    case fileStorage
    case secure

    @MainActor
    public func makeStorage(
        userDefaults: UserDefaults = .standard,
        userDefaultsKeyPrefix: String? = nil,
        fileDirectoryURL: URL? = nil,
        fileDirectoryName: String = "StorageModule",
        fileProtection: FileStorageProtection = .completeUntilFirstUserAuthentication,
        keychainService: String? = nil,
        keychainAccessGroup: String? = nil
    ) throws -> any Storage {
        switch self {
        case .userDefaults:
            UserDefaultsStorage(
                userDefaults: userDefaults,
                keyPrefix: userDefaultsKeyPrefix
            )
        case .fileStorage:
            try FileStorage(
                directoryURL: fileDirectoryURL,
                directoryName: fileDirectoryName,
                fileProtection: fileProtection
            )
        case .secure:
            KeychainStorage(
                service: keychainService,
                accessGroup: keychainAccessGroup
            )
        }
    }
}
