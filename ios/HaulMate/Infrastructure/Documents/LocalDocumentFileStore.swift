//
//  Created by Jerel Walters on 7/2/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation
import StorageModule

final class LocalDocumentFileStore: LocalDocumentFileStoring, @unchecked Sendable {
    private let protectedFileStore: any ProtectedFileStoring

    init(
        fileManager: FileManager = .default,
        directoryURL: URL? = nil,
        fileProtection: FileStorageProtection = .completeUntilFirstUserAuthentication
    ) {
        let resolvedDirectoryURL = directoryURL ?? fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HaulMateDocuments", isDirectory: true)

        protectedFileStore = ProtectedFileStore(
            directoryURL: resolvedDirectoryURL,
            fileProtection: fileProtection,
            fileManager: fileManager
        )
    }

    init(protectedFileStore: any ProtectedFileStoring) {
        self.protectedFileStore = protectedFileStore
    }

    func persistDocument(
        from sourceURL: URL,
        documentID: UUID,
        preferredFileName: String
    ) throws -> LocalStoredDocument {
        let storedFile = try protectedFileStore.storeFile(
            from: sourceURL,
            identifier: documentID.uuidString,
            preferredFileName: preferredFileName
        )

        return LocalStoredDocument(
            fileURL: storedFile.fileURL,
            fileName: storedFile.fileName,
            byteCount: storedFile.byteCount,
            sha256Hex: storedFile.sha256Hex
        )
    }

    func removeDocument(at fileURL: URL) throws {
        try protectedFileStore.removeFile(at: fileURL)
    }

    func removeAllDocuments() throws {
        try protectedFileStore.removeAllFiles()
    }
}
