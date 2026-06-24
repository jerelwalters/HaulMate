//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

@MainActor
public protocol Storage: AnyObject {
    func read<Value: Decodable>(
        _ type: Value.Type,
        for key: StorageKey
    ) throws -> Value?

    func save<Value: Encodable>(
        _ value: Value,
        for key: StorageKey
    ) throws

    func delete(_ key: StorageKey) throws
}

public struct StorageKey: Equatable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "StorageKey cannot be empty.")
        self.rawValue = rawValue
    }
}

extension StorageKey: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

public enum StorageError: Error, Equatable, Sendable {
    case decodingFailed(StorageKey)
    case keychainReadFailed(StorageKey, OSStatus)
    case keychainSaveFailed(StorageKey, OSStatus)
    case keychainDeleteFailed(StorageKey, OSStatus)
}
