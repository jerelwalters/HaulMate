//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

@MainActor
public final class FileStorage: Storage {
    private let directoryURL: URL
    private let fileProtection: FileStorageProtection
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        directoryURL: URL? = nil,
        directoryName: String = "StorageModule",
        fileProtection: FileStorageProtection = .completeUntilFirstUserAuthentication,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) throws {
        self.fileManager = fileManager
        self.fileProtection = fileProtection
        self.encoder = encoder
        self.decoder = decoder

        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let applicationSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.directoryURL = applicationSupportURL
                .appendingPathComponent(directoryName, isDirectory: true)
        }

        try createDirectoryIfNeeded()
    }

    public func read<Value: Decodable>(
        _ type: Value.Type,
        for key: StorageKey
    ) throws -> Value? {
        let url = fileURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let payload = try Data(contentsOf: url)

            return try decoder.decode(Value.self, from: payload)
        } catch is DecodingError {
            throw StorageError.decodingFailed(key)
        } catch {
            throw error
        }
    }

    public func save<Value: Encodable>(
        _ value: Value,
        for key: StorageKey
    ) throws {
        try createDirectoryIfNeeded()

        let payload = try encoder.encode(value)
        let url = fileURL(for: key)

        try payload.write(to: url, options: .atomic)
        try applyProtection(to: url)
    }

    public func delete(_ key: StorageKey) throws {
        let url = fileURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }

    private func createDirectoryIfNeeded() throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try applyProtection(to: directoryURL)
    }

    private func fileURL(for key: StorageKey) -> URL {
        directoryURL
            .appendingPathComponent(Self.fileName(for: key), isDirectory: false)
            .appendingPathExtension("json")
    }

    private static func fileName(for key: StorageKey) -> String {
        Data(key.rawValue.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func applyProtection(to url: URL) throws {
        #if os(iOS)
        guard let protectionValue = fileProtection.protectionValue else {
            return
        }

        try fileManager.setAttributes(
            [.protectionKey: protectionValue],
            ofItemAtPath: url.path
        )
        #else
        _ = url
        #endif
    }
}

public enum FileStorageProtection: Equatable, Sendable {
    case none
    case complete
    case completeUnlessOpen
    case completeUntilFirstUserAuthentication
}

#if os(iOS)
extension FileStorageProtection {
    var protectionValue: FileProtectionType? {
        switch self {
        case .none:
            nil
        case .complete:
            .complete
        case .completeUnlessOpen:
            .completeUnlessOpen
        case .completeUntilFirstUserAuthentication:
            .completeUntilFirstUserAuthentication
        }
    }
}
#endif
