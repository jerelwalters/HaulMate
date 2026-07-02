//
//  Created by Jerel Walters on 7/2/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import CryptoKit
import Foundation

public struct ProtectedStoredFile: Equatable, Sendable {
    public let fileURL: URL
    public let fileName: String
    public let byteCount: Int64
    public let sha256Hex: String

    public init(
        fileURL: URL,
        fileName: String,
        byteCount: Int64,
        sha256Hex: String
    ) {
        self.fileURL = fileURL
        self.fileName = fileName
        self.byteCount = byteCount
        self.sha256Hex = sha256Hex
    }
}

public protocol ProtectedFileStoring: AnyObject, Sendable {
    func storeFile(
        from sourceURL: URL,
        identifier: String,
        preferredFileName: String
    ) throws -> ProtectedStoredFile

    func removeFile(at fileURL: URL) throws
    func removeAllFiles() throws
}

public final class ProtectedFileStore: ProtectedFileStoring, @unchecked Sendable {
    private let directoryURL: URL
    private let fileProtection: FileStorageProtection
    private let fileManager: FileManager

    public init(
        directoryURL: URL,
        fileProtection: FileStorageProtection = .completeUntilFirstUserAuthentication,
        fileManager: FileManager = .default
    ) {
        self.directoryURL = directoryURL
        self.fileProtection = fileProtection
        self.fileManager = fileManager
    }

    public func storeFile(
        from sourceURL: URL,
        identifier: String,
        preferredFileName: String
    ) throws -> ProtectedStoredFile {
        try createDirectoryIfNeeded()

        let fileName = Self.sanitizedComponent(
            preferredFileName,
            fallback: "file"
        )
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension
        var destinationURL = directoryURL.appendingPathComponent(
            Self.sanitizedComponent(identifier, fallback: "file"),
            isDirectory: false
        )

        if !fileExtension.isEmpty {
            destinationURL.appendPathExtension(fileExtension)
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        try applyProtection(to: destinationURL)

        let data = try Data(contentsOf: destinationURL)
        let values = try destinationURL.resourceValues(forKeys: [.fileSizeKey])

        return ProtectedStoredFile(
            fileURL: destinationURL,
            fileName: fileName,
            byteCount: Int64(values.fileSize ?? data.count),
            sha256Hex: SHA256.hash(data: data).hexString
        )
    }

    public func removeFile(at fileURL: URL) throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        try fileManager.removeItem(at: fileURL)
    }

    public func removeAllFiles() throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }

        let fileURLs = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )

        for fileURL in fileURLs {
            try fileManager.removeItem(at: fileURL)
        }
    }

    private func createDirectoryIfNeeded() throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try applyProtection(to: directoryURL)
    }

    private func applyProtection(to fileURL: URL) throws {
        #if os(iOS)
        guard let protectionValue = fileProtection.protectionValue else {
            return
        }

        try fileManager.setAttributes(
            [.protectionKey: protectionValue],
            ofItemAtPath: fileURL.path
        )
        #else
        _ = fileURL
        #endif
    }

    private static func sanitizedComponent(
        _ value: String,
        fallback: String
    ) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.isEmpty ? fallback : trimmed
        let invalidCharacters = CharacterSet(charactersIn: "/\\:")
        let sanitized = candidate
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")

        return sanitized.isEmpty ? fallback : sanitized
    }
}

private extension SHA256.Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
