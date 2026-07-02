//
//  Created by Jerel Walters on 7/2/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

struct DocumentImportRequest: Equatable, Sendable {
    let sourceURL: URL
    let loadID: UUID?
    let kind: RecentDocumentKind
    let documentID: UUID
    let operationID: UUID
    let now: Date

    init(
        sourceURL: URL,
        loadID: UUID? = nil,
        kind: RecentDocumentKind,
        documentID: UUID = UUID(),
        operationID: UUID = UUID(),
        now: Date
    ) {
        self.sourceURL = sourceURL
        self.loadID = loadID
        self.kind = kind
        self.documentID = documentID
        self.operationID = operationID
        self.now = now
    }
}

struct DocumentImportResult: Equatable, Sendable {
    let document: RecentDocumentReference
    let queuedOperation: SyncOperation
}

struct LocalStoredDocument: Equatable, Sendable {
    let fileURL: URL
    let fileName: String
    let byteCount: Int64
    let sha256Hex: String
}

struct DocumentPipelineConfiguration: Equatable, Sendable {
    var maxByteCount: Int64

    static let `default` = DocumentPipelineConfiguration(
        maxByteCount: 25 * 1024 * 1024
    )
}

enum DocumentPipelineError: Error, Equatable, Sendable {
    case unsupportedFileType(String)
    case unreadableSource
    case fileTooLarge(byteCount: Int64, maxByteCount: Int64)
}

protocol LocalDocumentFileStoring: AnyObject, Sendable {
    func persistDocument(
        from sourceURL: URL,
        documentID: UUID,
        preferredFileName: String
    ) throws -> LocalStoredDocument

    func removeDocument(at fileURL: URL) throws
    func removeAllDocuments() throws
}

@MainActor
protocol DocumentMetadataStoring: AnyObject {
    func readRecentDocuments() throws -> RecentDocumentsSnapshot?
    func saveRecentDocuments(_ snapshot: RecentDocumentsSnapshot) throws
}

@MainActor
final class DocumentPipeline {
    private let metadataStore: any DocumentMetadataStoring
    private let fileStore: any LocalDocumentFileStoring
    private let syncEngine: SyncEngine
    private let configuration: DocumentPipelineConfiguration

    init(
        metadataStore: any DocumentMetadataStoring,
        fileStore: any LocalDocumentFileStoring,
        syncEngine: SyncEngine,
        configuration: DocumentPipelineConfiguration = .default
    ) {
        self.metadataStore = metadataStore
        self.fileStore = fileStore
        self.syncEngine = syncEngine
        self.configuration = configuration
    }

    func importDocument(_ request: DocumentImportRequest) throws -> DocumentImportResult {
        let content = try supportedContent(for: request.sourceURL)
        let startedAccess = request.sourceURL.startAccessingSecurityScopedResource()
        defer {
            if startedAccess {
                request.sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try validateSourceFile(at: request.sourceURL)

        let storedDocument = try fileStore.persistDocument(
            from: request.sourceURL,
            documentID: request.documentID,
            preferredFileName: request.sourceURL.lastPathComponent
        )

        do {
            let reference = RecentDocumentReference(
                id: request.documentID,
                loadID: request.loadID,
                kind: request.kind,
                fileName: storedDocument.fileName,
                contentType: content.contentType,
                byteCount: storedDocument.byteCount,
                sha256Hex: storedDocument.sha256Hex,
                localFileURL: storedDocument.fileURL,
                remoteObjectKey: nil,
                updatedAt: request.now
            )
            try save(reference, updatedAt: request.now)

            let operation = try syncEngine.enqueueDocumentUpload(
                payload: DocumentUploadSyncPayload(
                    documentID: reference.id,
                    loadID: reference.loadID,
                    fileName: reference.fileName,
                    contentType: reference.contentType,
                    byteCount: reference.byteCount,
                    sha256Hex: storedDocument.sha256Hex,
                    localFileURL: storedDocument.fileURL,
                    remoteObjectKey: reference.remoteObjectKey
                ),
                operationID: request.operationID,
                idempotencyKey: "document:\(request.documentID.uuidString):upload:v1",
                now: request.now
            )

            return DocumentImportResult(document: reference, queuedOperation: operation)
        } catch {
            try? fileStore.removeDocument(at: storedDocument.fileURL)
            throw error
        }
    }

    private func supportedContent(for fileURL: URL) throws -> SupportedDocumentContent {
        let fileExtension = fileURL.pathExtension.lowercased()
        guard let content = SupportedDocumentContent(fileExtension: fileExtension) else {
            throw DocumentPipelineError.unsupportedFileType(fileExtension)
        }

        return content
    }

    private func validateSourceFile(at fileURL: URL) throws {
        guard fileURL.isFileURL else {
            throw DocumentPipelineError.unreadableSource
        }

        let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let byteCount = values.fileSize.map(Int64.init) else {
            throw DocumentPipelineError.unreadableSource
        }
        guard byteCount <= configuration.maxByteCount else {
            throw DocumentPipelineError.fileTooLarge(
                byteCount: byteCount,
                maxByteCount: configuration.maxByteCount
            )
        }
    }

    private func save(_ reference: RecentDocumentReference, updatedAt: Date) throws {
        var documents = try metadataStore.readRecentDocuments()?.documents ?? []
        documents.removeAll { $0.id == reference.id }
        documents.insert(reference, at: 0)

        try metadataStore.saveRecentDocuments(
            RecentDocumentsSnapshot(
                documents: documents,
                updatedAt: updatedAt
            )
        )
    }
}

private struct SupportedDocumentContent: Equatable, Sendable {
    let contentType: String

    init?(fileExtension: String) {
        switch fileExtension {
        case "pdf":
            contentType = "application/pdf"
        case "jpg", "jpeg":
            contentType = "image/jpeg"
        case "png":
            contentType = "image/png"
        case "heic":
            contentType = "image/heic"
        case "heif":
            contentType = "image/heif"
        default:
            return nil
        }
    }
}

extension HaulMateLocalStorageRepository: DocumentMetadataStoring {}
