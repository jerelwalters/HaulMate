//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation
import Security

@MainActor
public final class KeychainStorage: Storage {
    private let service: String
    private let accessGroup: String?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        service: String? = nil,
        accessGroup: String? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        let resolvedService = service ?? Bundle.main.bundleIdentifier ?? "StorageModule"
        precondition(!resolvedService.isEmpty, "KeychainStorage service cannot be empty.")

        self.service = resolvedService
        self.accessGroup = accessGroup
        self.encoder = encoder
        self.decoder = decoder
    }

    public func read<Value: Decodable>(
        _ type: Value.Type,
        for key: StorageKey
    ) throws -> Value? {
        var query = itemQuery(for: key)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let payload = result as? Data else {
                throw StorageError.decodingFailed(key)
            }

            do {
                return try decoder.decode(Value.self, from: payload)
            } catch {
                throw StorageError.decodingFailed(key)
            }
        case errSecItemNotFound:
            return nil
        default:
            throw StorageError.keychainReadFailed(key, status)
        }
    }

    public func save<Value: Encodable>(
        _ value: Value,
        for key: StorageKey
    ) throws {
        let payload = try encoder.encode(value)
        let attributes: [String: Any] = [
            kSecValueData as String: payload
        ]

        let updateStatus = SecItemUpdate(
            itemQuery(for: key) as CFDictionary,
            attributes as CFDictionary
        )

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            try add(payload, for: key)
        default:
            throw StorageError.keychainSaveFailed(key, updateStatus)
        }
    }

    public func delete(_ key: StorageKey) throws {
        let status = SecItemDelete(itemQuery(for: key) as CFDictionary)

        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw StorageError.keychainDeleteFailed(key, status)
        }
    }

    private func add(_ payload: Data, for key: StorageKey) throws {
        var query = itemQuery(for: key)
        query[kSecValueData as String] = payload

        #if os(iOS)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #endif

        let status = SecItemAdd(query as CFDictionary, nil)

        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let retryStatus = SecItemUpdate(
                itemQuery(for: key) as CFDictionary,
                [kSecValueData as String: payload] as CFDictionary
            )

            guard retryStatus == errSecSuccess else {
                throw StorageError.keychainSaveFailed(key, retryStatus)
            }
        default:
            throw StorageError.keychainSaveFailed(key, status)
        }
    }

    private func itemQuery(for key: StorageKey) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}
