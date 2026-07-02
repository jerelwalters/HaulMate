//
//  Created by Jerel Walters on 7/1/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation
import StorageModule
import XCTest
@testable import HaulMate

@MainActor
final class SyncOutboxTests: XCTestCase {
    func testEnqueueLoadUpsertPersistsOperationAndSyncMetadata() throws {
        let repository = HaulMateLocalStorageRepository(storage: MemoryStorage())
        let engine = SyncEngine(outboxStore: repository, remote: RemoteSpy())

        let operation = try engine.enqueueLoadUpsert(
            payload: .sample,
            operationID: IDs.operation,
            idempotencyKey: "load:\(IDs.load.uuidString):v1",
            now: Dates.enqueued
        )

        let outbox = try XCTUnwrap(repository.readSyncOutbox())
        XCTAssertEqual(outbox.operations, [operation])
        XCTAssertEqual(outbox.operations.first?.state, .queued)
        XCTAssertEqual(outbox.operations.first?.idempotencyKey, "load:\(IDs.load.uuidString):v1")

        let metadata = try XCTUnwrap(repository.readSyncMetadata())
        XCTAssertEqual(metadata.pendingMutationCount, 1)
        XCTAssertEqual(metadata.failedMutationCount, 0)
        XCTAssertEqual(
            metadata.records,
            [
                SyncRecordMetadata(
                    id: IDs.operation,
                    entityKind: .load,
                    entityID: IDs.load,
                    state: .queued,
                    updatedAt: Dates.enqueued
                )
            ]
        )
    }

    func testDuplicateIdempotencyKeyReturnsExistingOperationWithoutDuplicatingOutboxEntry() throws {
        let repository = HaulMateLocalStorageRepository(storage: MemoryStorage())
        let engine = SyncEngine(outboxStore: repository, remote: RemoteSpy())

        let first = try engine.enqueueLoadUpsert(
            payload: .sample,
            operationID: IDs.operation,
            idempotencyKey: " load:\(IDs.load.uuidString):v1 ",
            now: Dates.enqueued
        )
        let duplicate = try engine.enqueueLoadUpsert(
            payload: .sample,
            operationID: IDs.secondOperation,
            idempotencyKey: "load:\(IDs.load.uuidString):v1",
            now: Dates.enqueued.addingTimeInterval(30)
        )

        XCTAssertEqual(duplicate, first)
        XCTAssertEqual(try repository.readSyncOutbox()?.operations.count, 1)
    }

    func testSyncPendingOperationMarksOperationAndRecordSynced() async throws {
        let repository = HaulMateLocalStorageRepository(storage: MemoryStorage())
        let remote = RemoteSpy(results: [
            .success(.applied(operationID: IDs.operation))
        ])
        let engine = SyncEngine(outboxStore: repository, remote: remote)
        try engine.enqueueLoadUpsert(
            payload: .sample,
            operationID: IDs.operation,
            idempotencyKey: "load:\(IDs.load.uuidString):v1",
            now: Dates.enqueued
        )

        let summary = try await engine.syncPendingOperations(now: Dates.synced)

        XCTAssertEqual(summary, SyncRunSummary(attemptedCount: 1, syncedCount: 1, failedCount: 0, needsReviewCount: 0))
        XCTAssertEqual(remote.appliedOperations.map(\.id), [IDs.operation])

        let operation = try XCTUnwrap(repository.readSyncOutbox()?.operations.first)
        XCTAssertEqual(operation.state, .synced)
        XCTAssertEqual(operation.attemptCount, 1)
        XCTAssertNil(operation.lastErrorMessage)
        XCTAssertEqual(operation.serverResult?.result, .applied)

        let metadata = try XCTUnwrap(repository.readSyncMetadata())
        XCTAssertEqual(metadata.lastSuccessfulSyncAt, Dates.synced)
        XCTAssertEqual(metadata.pendingMutationCount, 0)
        XCTAssertEqual(metadata.failedMutationCount, 0)
        XCTAssertEqual(metadata.records.first?.state, .synced)
    }

    func testSyncPendingDocumentUploadMarksOperationAndRecordSynced() async throws {
        let repository = HaulMateLocalStorageRepository(storage: MemoryStorage())
        let remote = SyncRemoteSpy(results: [
            .success(.documentApplied(operationID: IDs.documentOperation))
        ])
        let engine = SyncEngine(outboxStore: repository, remote: remote)
        try engine.enqueueDocumentUpload(
            payload: .sample,
            operationID: IDs.documentOperation,
            idempotencyKey: "document:\(IDs.document.uuidString):upload:v1",
            now: Dates.enqueued
        )

        let summary = try await engine.syncPendingOperations(now: Dates.synced)

        XCTAssertEqual(summary, SyncRunSummary(attemptedCount: 1, syncedCount: 1, failedCount: 0, needsReviewCount: 0))
        XCTAssertEqual(remote.appliedOperations.map(\.kind), [.documentUpload])

        let operation = try XCTUnwrap(repository.readSyncOutbox()?.operations.first)
        XCTAssertEqual(operation.state, .synced)
        XCTAssertEqual(operation.entityKind, .document)
        XCTAssertEqual(operation.serverResult?.targetTable, "documents")

        let metadata = try XCTUnwrap(repository.readSyncMetadata())
        XCTAssertEqual(metadata.lastSuccessfulSyncAt, Dates.synced)
        XCTAssertEqual(metadata.pendingMutationCount, 0)
        XCTAssertEqual(metadata.records.first?.entityKind, .document)
        XCTAssertEqual(metadata.records.first?.state, .synced)
    }

    func testLoadOnlyRemoteFailsUnsupportedDocumentUploadWithoutCallingLoadAdapter() async throws {
        let repository = HaulMateLocalStorageRepository(storage: MemoryStorage())
        let remote = RemoteSpy()
        let engine = SyncEngine(
            outboxStore: repository,
            remote: remote,
            retryPolicy: SyncRetryPolicy(retryDelay: 60, inFlightTimeout: 300)
        )
        try engine.enqueueDocumentUpload(
            payload: .sample,
            operationID: IDs.documentOperation,
            idempotencyKey: "document:\(IDs.document.uuidString):upload:v1",
            now: Dates.enqueued
        )

        let summary = try await engine.syncPendingOperations(now: Dates.firstAttempt)

        XCTAssertEqual(summary, SyncRunSummary(attemptedCount: 1, syncedCount: 0, failedCount: 1, needsReviewCount: 0))
        XCTAssertTrue(remote.appliedOperations.isEmpty)

        let operation = try XCTUnwrap(repository.readSyncOutbox()?.operations.first)
        XCTAssertEqual(operation.state, .failed)
        XCTAssertEqual(operation.nextRetryAt, Dates.retryDue)
        XCTAssertEqual(operation.lastErrorMessage, "Unsupported sync operation: document.upload")
    }

    func testFailedOperationRetriesAfterRestartWhenRetryIsDue() async throws {
        let repository = HaulMateLocalStorageRepository(storage: MemoryStorage())
        let failingRemote = RemoteSpy(results: [
            .failure(RemoteError.transportUnavailable)
        ])
        let firstEngine = SyncEngine(
            outboxStore: repository,
            remote: failingRemote,
            retryPolicy: SyncRetryPolicy(retryDelay: 60, inFlightTimeout: 300)
        )
        try firstEngine.enqueueLoadUpsert(
            payload: .sample,
            operationID: IDs.operation,
            idempotencyKey: "load:\(IDs.load.uuidString):v1",
            now: Dates.enqueued
        )

        let failedSummary = try await firstEngine.syncPendingOperations(now: Dates.firstAttempt)

        XCTAssertEqual(failedSummary.failedCount, 1)
        XCTAssertEqual(try repository.readSyncOutbox()?.operations.first?.state, .failed)
        XCTAssertEqual(try repository.readSyncOutbox()?.operations.first?.nextRetryAt, Dates.retryDue)

        let restartedRemote = RemoteSpy(results: [
            .success(.applied(operationID: IDs.operation))
        ])
        let restartedEngine = SyncEngine(
            outboxStore: repository,
            remote: restartedRemote,
            retryPolicy: SyncRetryPolicy(retryDelay: 60, inFlightTimeout: 300)
        )

        let earlySummary = try await restartedEngine.syncPendingOperations(now: Dates.retryDue.addingTimeInterval(-1))
        XCTAssertEqual(earlySummary, .empty)
        XCTAssertTrue(restartedRemote.appliedOperations.isEmpty)

        let retrySummary = try await restartedEngine.syncPendingOperations(now: Dates.retryDue)

        XCTAssertEqual(retrySummary.syncedCount, 1)
        XCTAssertEqual(restartedRemote.appliedOperations.map(\.id), [IDs.operation])
        XCTAssertEqual(try repository.readSyncOutbox()?.operations.first?.state, .synced)
        XCTAssertEqual(try repository.readSyncOutbox()?.operations.first?.attemptCount, 2)
    }

    func testStaleInFlightOperationRetriesAfterRestartTimeout() async throws {
        let repository = HaulMateLocalStorageRepository(storage: MemoryStorage())
        var operation = try SyncOperation.loadUpsert(
            id: IDs.operation,
            idempotencyKey: "load:\(IDs.load.uuidString):v1",
            payload: .sample,
            createdAt: Dates.enqueued
        )
        operation.markSyncing(at: Dates.firstAttempt)
        try repository.saveSyncOutbox(
            SyncOutboxSnapshot(
                operations: [operation],
                updatedAt: Dates.firstAttempt
            )
        )
        let remote = RemoteSpy(results: [
            .success(.applied(operationID: IDs.operation))
        ])
        let restartedEngine = SyncEngine(
            outboxStore: repository,
            remote: remote,
            retryPolicy: SyncRetryPolicy(retryDelay: 60, inFlightTimeout: 300)
        )

        let earlySummary = try await restartedEngine.syncPendingOperations(
            now: Dates.firstAttempt.addingTimeInterval(299)
        )
        XCTAssertEqual(earlySummary, .empty)
        XCTAssertTrue(remote.appliedOperations.isEmpty)

        let retrySummary = try await restartedEngine.syncPendingOperations(
            now: Dates.firstAttempt.addingTimeInterval(300)
        )

        XCTAssertEqual(retrySummary.syncedCount, 1)
        XCTAssertEqual(remote.appliedOperations.map(\.id), [IDs.operation])
        XCTAssertEqual(try repository.readSyncOutbox()?.operations.first?.state, .synced)
        XCTAssertEqual(try repository.readSyncOutbox()?.operations.first?.attemptCount, 2)
    }

    func testFinancialConflictRequiresReviewAndDoesNotScheduleRetry() async throws {
        let repository = HaulMateLocalStorageRepository(storage: MemoryStorage())
        let remote = RemoteSpy(results: [
            .success(.financialConflict(operationID: IDs.operation))
        ])
        let engine = SyncEngine(outboxStore: repository, remote: remote)
        try engine.enqueueLoadUpsert(
            payload: .sample,
            operationID: IDs.operation,
            idempotencyKey: "load:\(IDs.load.uuidString):v1",
            now: Dates.enqueued
        )

        let summary = try await engine.syncPendingOperations(now: Dates.firstAttempt)

        XCTAssertEqual(summary, SyncRunSummary(attemptedCount: 1, syncedCount: 0, failedCount: 0, needsReviewCount: 1))
        let operation = try XCTUnwrap(repository.readSyncOutbox()?.operations.first)
        XCTAssertEqual(operation.state, .needsReview)
        XCTAssertEqual(operation.reviewReason, .financialConflict)
        XCTAssertNil(operation.nextRetryAt)
        XCTAssertEqual(operation.serverResult?.errorCode, .financialConflict)

        let metadata = try XCTUnwrap(repository.readSyncMetadata())
        XCTAssertEqual(metadata.failedMutationCount, 1)
        XCTAssertEqual(metadata.records.first?.state, .needsReview)
        XCTAssertEqual(metadata.records.first?.lastErrorMessage, "Financial conflict requires review before retrying.")
    }
}

@MainActor
private final class SyncRemoteSpy: SyncRemoteApplying {
    private var results: [Result<SyncOperationServerResult, Error>]
    private(set) var appliedOperations: [SyncOperation] = []

    init(results: [Result<SyncOperationServerResult, Error>] = []) {
        self.results = results
    }

    func applySyncOperation(_ operation: SyncOperation) async throws -> SyncOperationServerResult {
        appliedOperations.append(operation)

        guard !results.isEmpty else {
            return .applied(operationID: operation.id)
        }

        return try results.removeFirst().get()
    }
}

@MainActor
private final class RemoteSpy: LoadSyncRemoteApplying {
    private var results: [Result<SyncOperationServerResult, Error>]
    private(set) var appliedOperations: [SyncOperation] = []

    init(results: [Result<SyncOperationServerResult, Error>] = []) {
        self.results = results
    }

    func applyLoadSyncOperation(_ operation: SyncOperation) async throws -> SyncOperationServerResult {
        appliedOperations.append(operation)

        guard !results.isEmpty else {
            return .applied(operationID: operation.id)
        }

        return try results.removeFirst().get()
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

private enum RemoteError: Error {
    case transportUnavailable
}

private enum IDs {
    static let operation = UUID(uuidString: "00000000-0000-0000-0000-000000000901")!
    static let secondOperation = UUID(uuidString: "00000000-0000-0000-0000-000000000902")!
    static let documentOperation = UUID(uuidString: "00000000-0000-0000-0000-000000000903")!
    static let load = UUID(uuidString: "00000000-0000-0000-0000-000000000691")!
    static let customer = UUID(uuidString: "00000000-0000-0000-0000-000000000591")!
    static let document = UUID(uuidString: "00000000-0000-0000-0000-000000000491")!
}

private enum Dates {
    static let enqueued = Date(timeIntervalSince1970: 1_000)
    static let firstAttempt = Date(timeIntervalSince1970: 1_100)
    static let retryDue = Date(timeIntervalSince1970: 1_160)
    static let synced = Date(timeIntervalSince1970: 1_300)
}

private extension LoadSyncPayload {
    static let sample = LoadSyncPayload(
        loadID: IDs.load,
        customerID: IDs.customer,
        referenceNumber: "RC-4182",
        status: .accepted,
        lineHaulRate: Decimal(1_850),
        loadedMiles: Decimal(540)
    )
}

private extension DocumentUploadSyncPayload {
    static let sample = DocumentUploadSyncPayload(
        documentID: IDs.document,
        loadID: IDs.load,
        fileName: "pod.pdf",
        contentType: "application/pdf",
        byteCount: 17,
        sha256Hex: String(repeating: "a", count: 64),
        localFileURL: URL(fileURLWithPath: "/tmp/haulmate/pod.pdf")
    )
}

private extension SyncOperationServerResult {
    static func applied(operationID: UUID) -> SyncOperationServerResult {
        SyncOperationServerResult(
            operationID: operationID,
            idempotencyKey: "load:\(IDs.load.uuidString):v1",
            operationType: .loadUpsert,
            targetID: IDs.load,
            result: .applied,
            reconciliation: SyncReconciliationMetadata(
                serverCreatedAt: Dates.synced,
                serverUpdatedAt: Dates.synced,
                serverStatus: .accepted
            )
        )
    }

    static func financialConflict(operationID: UUID) -> SyncOperationServerResult {
        SyncOperationServerResult(
            operationID: operationID,
            idempotencyKey: "load:\(IDs.load.uuidString):v1",
            operationType: .loadUpsert,
            targetID: IDs.load,
            result: .rejected,
            errorCode: .financialConflict
        )
    }

    static func documentApplied(operationID: UUID) -> SyncOperationServerResult {
        SyncOperationServerResult(
            operationID: operationID,
            idempotencyKey: "document:\(IDs.document.uuidString):upload:v1",
            operationType: .documentUpload,
            targetTable: "documents",
            targetID: IDs.document,
            result: .applied
        )
    }
}
