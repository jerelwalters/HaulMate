//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

@MainActor
public final class UserDefaultsStorage: Storage {
    private let userDefaults: UserDefaults
    private let keyPrefix: String?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        userDefaults: UserDefaults = .standard,
        keyPrefix: String? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.userDefaults = userDefaults
        self.keyPrefix = keyPrefix
        self.encoder = encoder
        self.decoder = decoder
    }

    public func read<Value: Decodable>(
        _ type: Value.Type,
        for key: StorageKey
    ) throws -> Value? {
        let defaultsKey = defaultsKey(for: key)
        guard let object = userDefaults.object(forKey: defaultsKey) else {
            return nil
        }

        guard let payload = object as? Data else {
            throw StorageError.decodingFailed(key)
        }

        do {
            return try decoder.decode(Value.self, from: payload)
        } catch {
            throw StorageError.decodingFailed(key)
        }
    }

    public func save<Value: Encodable>(
        _ value: Value,
        for key: StorageKey
    ) throws {
        let payload = try encoder.encode(value)

        userDefaults.set(payload, forKey: defaultsKey(for: key))
    }

    public func delete(_ key: StorageKey) throws {
        userDefaults.removeObject(forKey: defaultsKey(for: key))
    }

    private func defaultsKey(for key: StorageKey) -> String {
        guard let keyPrefix else {
            return key.rawValue
        }

        return keyPrefix + key.rawValue
    }
}
