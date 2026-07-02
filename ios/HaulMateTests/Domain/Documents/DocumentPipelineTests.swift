//
//  Created by Jerel Walters on 7/2/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import CryptoKit
import StorageModule
import XCTest
@testable import HaulMate

@MainActor
final class DocumentPipelineTests: XCTestCase {
    func testImportDocumentCopiesHashesPersistsMetadataAndQueuesUpload() throws {
        let context = try TestContext()
        addTeardownBlock { try? FileManager.default.removeItem(at: context.rootURL) }
        let sourceURL = try context.writeSourceFile(
            named: "pod.pdf",
            data: Data("proof-of-delivery".utf8)
        )
        let pipeline = context.makePipeline()

        let result = try pipeline.importDocument(
            DocumentImportRequest(
                sourceURL: sourceURL,
                loadID: IDs.load,
                kind: .proofOfDelivery,
                documentID: IDs.document,
                operationID: IDs.operation,
                now: Dates.imported
            )
        )

        XCTAssertEqual(result.document.id, IDs.document)
        XCTAssertEqual(result.document.loadID, IDs.load)
        XCTAssertEqual(result.document.kind, .proofOfDelivery)
        XCTAssertEqual(result.document.fileName, "pod.pdf")
        XCTAssertEqual(result.document.contentType, "application/pdf")
        XCTAssertEqual(result.document.byteCount, 17)
        XCTAssertEqual(result.document.sha256Hex, Data("proof-of-delivery".utf8).sha256Hex)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(result.document.localFileURL).path))

        let snapshot = try XCTUnwrap(context.repository.readRecentDocuments())
        XCTAssertEqual(snapshot.documents, [result.document])
        XCTAssertEqual(snapshot.updatedAt, Dates.imported)

        let operation = try XCTUnwrap(context.repository.readSyncOutbox()?.operations.first)
        XCTAssertEqual(operation, result.queuedOperation)
        XCTAssertEqual(operation.kind, .documentUpload)
        XCTAssertEqual(operation.entityKind, .document)
        XCTAssertEqual(operation.entityID, IDs.document)
        XCTAssertEqual(operation.idempotencyKey, "document:\(IDs.document.uuidString):upload:v1")
        guard case .documentUpload(let payload) = operation.payload else {
            return XCTFail("Expected document upload payload.")
        }
        XCTAssertEqual(payload.documentID, IDs.document)
        XCTAssertEqual(payload.loadID, IDs.load)
        XCTAssertEqual(payload.sha256Hex, Data("proof-of-delivery".utf8).sha256Hex)
    }

    func testUnsupportedFileTypeDoesNotPersistMetadataOrQueueUpload() throws {
        let context = try TestContext()
        addTeardownBlock { try? FileManager.default.removeItem(at: context.rootURL) }
        let sourceURL = try context.writeSourceFile(
            named: "notes.txt",
            data: Data("private note".utf8)
        )
        let pipeline = context.makePipeline()

        XCTAssertThrowsError(
            try pipeline.importDocument(
                DocumentImportRequest(
                    sourceURL: sourceURL,
                    kind: .otherEvidence,
                    documentID: IDs.document,
                    operationID: IDs.operation,
                    now: Dates.imported
                )
            )
        ) { error in
            XCTAssertEqual(error as? DocumentPipelineError, .unsupportedFileType("txt"))
        }
        XCTAssertNil(try context.repository.readRecentDocuments())
        XCTAssertNil(try context.repository.readSyncOutbox())
    }

    func testOversizedFileDoesNotPersistMetadataOrQueueUpload() throws {
        let context = try TestContext()
        addTeardownBlock { try? FileManager.default.removeItem(at: context.rootURL) }
        let sourceURL = try context.writeSourceFile(
            named: "pod.pdf",
            data: Data(repeating: 0x01, count: 4)
        )
        let pipeline = context.makePipeline(
            configuration: DocumentPipelineConfiguration(maxByteCount: 3)
        )

        XCTAssertThrowsError(
            try pipeline.importDocument(
                DocumentImportRequest(
                    sourceURL: sourceURL,
                    kind: .proofOfDelivery,
                    documentID: IDs.document,
                    operationID: IDs.operation,
                    now: Dates.imported
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? DocumentPipelineError,
                .fileTooLarge(byteCount: 4, maxByteCount: 3)
            )
        }
        XCTAssertNil(try context.repository.readRecentDocuments())
        XCTAssertNil(try context.repository.readSyncOutbox())
    }
}

@MainActor
private struct TestContext {
    let rootURL: URL
    let sourceDirectoryURL: URL
    let documentsDirectoryURL: URL
    let repository: HaulMateLocalStorageRepository

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.haulmate.document-pipeline-tests.\(UUID().uuidString)", isDirectory: true)
        sourceDirectoryURL = rootURL.appendingPathComponent("Source", isDirectory: true)
        documentsDirectoryURL = rootURL.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(
            at: sourceDirectoryURL,
            withIntermediateDirectories: true
        )
        repository = HaulMateLocalStorageRepository(storage: MemoryStorage())
    }

    func makePipeline(
        configuration: DocumentPipelineConfiguration = .default
    ) -> DocumentPipeline {
        DocumentPipeline(
            metadataStore: repository,
            fileStore: LocalDocumentFileStore(directoryURL: documentsDirectoryURL),
            syncEngine: SyncEngine(outboxStore: repository, remote: RemoteSpy()),
            configuration: configuration
        )
    }

    func writeSourceFile(named fileName: String, data: Data) throws -> URL {
        let fileURL = sourceDirectoryURL.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }
}

@MainActor
private final class RemoteSpy: LoadSyncRemoteApplying {
    func applyLoadSyncOperation(_ operation: SyncOperation) async throws -> SyncOperationServerResult {
        SyncOperationServerResult(
            operationID: operation.id,
            idempotencyKey: operation.idempotencyKey,
            operationType: operation.kind,
            targetTable: "documents",
            targetID: operation.entityID,
            result: .applied
        )
    }
}

@MainActor
private final class MemoryStorage: Storage {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var payloads: [StorageKey: Data] = [:]

    func read<Value: Decodable>(
        _ type: Value.Type,
        for key: StorageKey
    ) throws -> Value? {
        guard let payload = payloads[key] else {
            return nil
        }

        do {
            return try decoder.decode(Value.self, from: payload)
        } catch {
            throw StorageError.decodingFailed(key)
        }
    }

    func save<Value: Encodable>(
        _ value: Value,
        for key: StorageKey
    ) throws {
        payloads[key] = try encoder.encode(value)
    }

    func delete(_ key: StorageKey) {
        payloads.removeValue(forKey: key)
    }
}

private enum IDs {
    static let load = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let document = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let operation = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
}

private enum Dates {
    static let imported = Date(timeIntervalSince1970: 1_000)
}

private extension Data {
    var sha256Hex: String {
        SHA256.hash(data: self)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
