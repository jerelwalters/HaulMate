//
//  Created by Jerel Walters on 7/1/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

struct LoadSyncPayload: Codable, Equatable, Sendable {
    let loadID: UUID
    let customerID: UUID
    let referenceNumber: String
    let status: LoadStatus
    let lineHaulRate: Decimal
    let loadedMiles: Decimal
    let expectedServerUpdatedAt: Date?

    init(
        loadID: UUID,
        customerID: UUID,
        referenceNumber: String,
        status: LoadStatus,
        lineHaulRate: Decimal,
        loadedMiles: Decimal,
        expectedServerUpdatedAt: Date? = nil
    ) {
        self.loadID = loadID
        self.customerID = customerID
        self.referenceNumber = referenceNumber
        self.status = status
        self.lineHaulRate = lineHaulRate
        self.loadedMiles = loadedMiles
        self.expectedServerUpdatedAt = expectedServerUpdatedAt
    }
}

struct DocumentUploadSyncPayload: Codable, Equatable, Sendable {
    let documentID: UUID
    let loadID: UUID?
    let fileName: String
    let contentType: String
    let byteCount: Int64
    let sha256Hex: String
    let localFileURL: URL
    let remoteObjectKey: String?

    init(
        documentID: UUID,
        loadID: UUID?,
        fileName: String,
        contentType: String,
        byteCount: Int64,
        sha256Hex: String,
        localFileURL: URL,
        remoteObjectKey: String? = nil
    ) {
        self.documentID = documentID
        self.loadID = loadID
        self.fileName = fileName
        self.contentType = contentType
        self.byteCount = byteCount
        self.sha256Hex = sha256Hex
        self.localFileURL = localFileURL
        self.remoteObjectKey = remoteObjectKey
    }
}

enum SyncOperationPayload: Codable, Equatable, Sendable {
    case load(LoadSyncPayload)
    case documentUpload(DocumentUploadSyncPayload)
}

struct SyncOutboxSnapshot: Codable, Equatable, Sendable {
    var operations: [SyncOperation]
    var updatedAt: Date

    init(
        operations: [SyncOperation] = [],
        updatedAt: Date
    ) {
        self.operations = operations
        self.updatedAt = updatedAt
    }
}

struct SyncOperation: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let idempotencyKey: String
    let kind: SyncOperationKind
    let entityKind: SyncRecordEntityKind
    let entityID: UUID
    let payload: SyncOperationPayload
    let createdAt: Date
    var state: SyncOperationState
    var attemptCount: Int
    var nextRetryAt: Date?
    var lastErrorMessage: String?
    var reviewReason: SyncReviewReason?
    var serverResult: SyncOperationServerResult?
    var updatedAt: Date

    private init(
        id: UUID,
        idempotencyKey: String,
        kind: SyncOperationKind,
        entityKind: SyncRecordEntityKind,
        entityID: UUID,
        payload: SyncOperationPayload,
        createdAt: Date,
        state: SyncOperationState,
        attemptCount: Int,
        nextRetryAt: Date?,
        lastErrorMessage: String?,
        reviewReason: SyncReviewReason?,
        serverResult: SyncOperationServerResult?,
        updatedAt: Date
    ) {
        self.id = id
        self.idempotencyKey = idempotencyKey
        self.kind = kind
        self.entityKind = entityKind
        self.entityID = entityID
        self.payload = payload
        self.createdAt = createdAt
        self.state = state
        self.attemptCount = attemptCount
        self.nextRetryAt = nextRetryAt
        self.lastErrorMessage = lastErrorMessage
        self.reviewReason = reviewReason
        self.serverResult = serverResult
        self.updatedAt = updatedAt
    }

    static func loadUpsert(
        id: UUID = UUID(),
        idempotencyKey: String,
        payload: LoadSyncPayload,
        createdAt: Date
    ) throws -> SyncOperation {
        let normalizedKey = idempotencyKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            throw SyncOperationValidationError.emptyIdempotencyKey
        }
        guard normalizedKey.count <= 160 else {
            throw SyncOperationValidationError.idempotencyKeyTooLong
        }

        return SyncOperation(
            id: id,
            idempotencyKey: normalizedKey,
            kind: .loadUpsert,
            entityKind: .load,
            entityID: payload.loadID,
            payload: .load(payload),
            createdAt: createdAt,
            state: .queued,
            attemptCount: 0,
            nextRetryAt: nil,
            lastErrorMessage: nil,
            reviewReason: nil,
            serverResult: nil,
            updatedAt: createdAt
        )
    }

    static func documentUpload(
        id: UUID = UUID(),
        idempotencyKey: String,
        payload: DocumentUploadSyncPayload,
        createdAt: Date
    ) throws -> SyncOperation {
        let normalizedKey = idempotencyKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            throw SyncOperationValidationError.emptyIdempotencyKey
        }
        guard normalizedKey.count <= 160 else {
            throw SyncOperationValidationError.idempotencyKeyTooLong
        }

        return SyncOperation(
            id: id,
            idempotencyKey: normalizedKey,
            kind: .documentUpload,
            entityKind: .document,
            entityID: payload.documentID,
            payload: .documentUpload(payload),
            createdAt: createdAt,
            state: .queued,
            attemptCount: 0,
            nextRetryAt: nil,
            lastErrorMessage: nil,
            reviewReason: nil,
            serverResult: nil,
            updatedAt: createdAt
        )
    }

    func isReadyToSync(
        asOf date: Date,
        inFlightTimeout: TimeInterval
    ) -> Bool {
        switch state {
        case .queued:
            return true
        case .failed:
            return nextRetryAt.map { $0 <= date } ?? false
        case .syncing:
            return updatedAt.addingTimeInterval(inFlightTimeout) <= date
        case .synced, .needsReview:
            return false
        }
    }

    mutating func markSyncing(at date: Date) {
        state = .syncing
        attemptCount += 1
        nextRetryAt = nil
        lastErrorMessage = nil
        reviewReason = nil
        updatedAt = date
    }

    mutating func markSynced(
        result: SyncOperationServerResult,
        at date: Date
    ) {
        state = .synced
        nextRetryAt = nil
        lastErrorMessage = nil
        reviewReason = nil
        serverResult = result
        updatedAt = date
    }

    mutating func markFailed(
        message: String,
        nextRetryAt: Date?,
        at date: Date
    ) {
        state = .failed
        self.nextRetryAt = nextRetryAt
        lastErrorMessage = message
        reviewReason = nil
        updatedAt = date
    }

    mutating func markNeedsReview(
        reason: SyncReviewReason,
        message: String,
        result: SyncOperationServerResult,
        at date: Date
    ) {
        state = .needsReview
        nextRetryAt = nil
        lastErrorMessage = message
        reviewReason = reason
        serverResult = result
        updatedAt = date
    }
}

enum SyncOperationKind: String, Codable, Sendable {
    case loadUpsert = "load.upsert"
    case documentUpload = "document.upload"
}

enum SyncOperationState: String, Codable, Sendable {
    case queued
    case syncing
    case synced
    case failed
    case needsReview
}

enum SyncOperationValidationError: Error, Equatable, Sendable {
    case emptyIdempotencyKey
    case idempotencyKeyTooLong
}

enum SyncReviewReason: String, Codable, Sendable {
    case financialConflict
}

struct SyncOperationServerResult: Codable, Equatable, Sendable {
    let operationID: UUID
    let idempotencyKey: String
    let operationType: SyncOperationKind
    let targetTable: String
    let targetID: UUID
    let result: SyncOperationServerResultStatus
    let errorCode: SyncOperationRejectionCode?
    let reconciliation: SyncReconciliationMetadata?

    init(
        operationID: UUID,
        idempotencyKey: String,
        operationType: SyncOperationKind,
        targetTable: String = "loads",
        targetID: UUID,
        result: SyncOperationServerResultStatus,
        errorCode: SyncOperationRejectionCode? = nil,
        reconciliation: SyncReconciliationMetadata? = nil
    ) {
        self.operationID = operationID
        self.idempotencyKey = idempotencyKey
        self.operationType = operationType
        self.targetTable = targetTable
        self.targetID = targetID
        self.result = result
        self.errorCode = errorCode
        self.reconciliation = reconciliation
    }
}

enum SyncOperationServerResultStatus: String, Codable, Sendable {
    case applied
    case rejected
}

enum SyncOperationRejectionCode: String, Codable, Sendable {
    case staleServerRecord = "stale_server_record"
    case missingServerRecord = "missing_server_record"
    case invalidStatusTransition = "invalid_status_transition"
    case financialConflict = "financial_conflict"
}

struct SyncReconciliationMetadata: Codable, Equatable, Sendable {
    let serverCreatedAt: Date?
    let serverUpdatedAt: Date?
    let serverStatus: LoadStatus?

    init(
        serverCreatedAt: Date? = nil,
        serverUpdatedAt: Date? = nil,
        serverStatus: LoadStatus? = nil
    ) {
        self.serverCreatedAt = serverCreatedAt
        self.serverUpdatedAt = serverUpdatedAt
        self.serverStatus = serverStatus
    }
}

@MainActor
protocol SyncOutboxStoring: AnyObject {
    func readSyncOutbox() throws -> SyncOutboxSnapshot?
    func saveSyncOutbox(_ snapshot: SyncOutboxSnapshot) throws
    func readSyncMetadata() throws -> SyncMetadataSnapshot?
    func saveSyncMetadata(_ snapshot: SyncMetadataSnapshot) throws
}

@MainActor
protocol SyncRemoteApplying {
    func applySyncOperation(_ operation: SyncOperation) async throws -> SyncOperationServerResult
}

@MainActor
protocol LoadSyncRemoteApplying: SyncRemoteApplying {
    func applyLoadSyncOperation(_ operation: SyncOperation) async throws -> SyncOperationServerResult
}

extension LoadSyncRemoteApplying {
    func applySyncOperation(_ operation: SyncOperation) async throws -> SyncOperationServerResult {
        guard operation.kind == .loadUpsert else {
            throw SyncRemoteApplicationError.unsupportedOperation(operation.kind)
        }

        return try await applyLoadSyncOperation(operation)
    }
}

enum SyncRemoteApplicationError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedOperation(SyncOperationKind)

    var errorDescription: String? {
        switch self {
        case .unsupportedOperation(let operationKind):
            return "Unsupported sync operation: \(operationKind.rawValue)"
        }
    }
}

struct SyncRetryPolicy: Equatable, Sendable {
    var retryDelay: TimeInterval
    var inFlightTimeout: TimeInterval

    static let `default` = SyncRetryPolicy(
        retryDelay: 30,
        inFlightTimeout: 5 * 60
    )
}

struct SyncRunSummary: Equatable, Sendable {
    var attemptedCount: Int
    var syncedCount: Int
    var failedCount: Int
    var needsReviewCount: Int

    static let empty = SyncRunSummary(
        attemptedCount: 0,
        syncedCount: 0,
        failedCount: 0,
        needsReviewCount: 0
    )
}

@MainActor
final class SyncEngine {
    private let outboxStore: any SyncOutboxStoring
    private let remote: any SyncRemoteApplying
    private let retryPolicy: SyncRetryPolicy

    init(
        outboxStore: any SyncOutboxStoring,
        remote: any SyncRemoteApplying,
        retryPolicy: SyncRetryPolicy = .default
    ) {
        self.outboxStore = outboxStore
        self.remote = remote
        self.retryPolicy = retryPolicy
    }

    @discardableResult
    func enqueueLoadUpsert(
        payload: LoadSyncPayload,
        operationID: UUID = UUID(),
        idempotencyKey: String,
        now: Date
    ) throws -> SyncOperation {
        var snapshot = try readSnapshot(defaultUpdatedAt: now)
        let normalizedKey = idempotencyKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if let duplicate = snapshot.operations.first(where: { $0.idempotencyKey == normalizedKey }) {
            return duplicate
        }

        let operation = try SyncOperation.loadUpsert(
            id: operationID,
            idempotencyKey: normalizedKey,
            payload: payload,
            createdAt: now
        )
        snapshot.operations.append(operation)
        snapshot.updatedAt = now

        try persist(snapshot, now: now)

        return operation
    }

    @discardableResult
    func enqueueDocumentUpload(
        payload: DocumentUploadSyncPayload,
        operationID: UUID = UUID(),
        idempotencyKey: String,
        now: Date
    ) throws -> SyncOperation {
        var snapshot = try readSnapshot(defaultUpdatedAt: now)
        let normalizedKey = idempotencyKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if let duplicate = snapshot.operations.first(where: { $0.idempotencyKey == normalizedKey }) {
            return duplicate
        }

        let operation = try SyncOperation.documentUpload(
            id: operationID,
            idempotencyKey: normalizedKey,
            payload: payload,
            createdAt: now
        )
        snapshot.operations.append(operation)
        snapshot.updatedAt = now

        try persist(snapshot, now: now)

        return operation
    }

    func syncPendingOperations(now: Date) async throws -> SyncRunSummary {
        var snapshot = try readSnapshot(defaultUpdatedAt: now)
        let dueOperationIDs = snapshot.operations
            .filter { $0.isReadyToSync(asOf: now, inFlightTimeout: retryPolicy.inFlightTimeout) }
            .map(\.id)

        guard !dueOperationIDs.isEmpty else {
            return .empty
        }

        var summary = SyncRunSummary.empty

        for operationID in dueOperationIDs {
            guard let startIndex = snapshot.operations.firstIndex(where: { $0.id == operationID }) else {
                continue
            }

            snapshot.operations[startIndex].markSyncing(at: now)
            snapshot.updatedAt = now
            try persist(snapshot, now: now)
            summary.attemptedCount += 1

            do {
                let result = try await remote.applySyncOperation(snapshot.operations[startIndex])
                guard let completedIndex = snapshot.operations.firstIndex(where: { $0.id == operationID }) else {
                    continue
                }

                switch result.result {
                case .applied:
                    snapshot.operations[completedIndex].markSynced(result: result, at: now)
                    summary.syncedCount += 1
                    snapshot.updatedAt = now
                    try persist(snapshot, now: now, lastSuccessfulSyncAt: now)
                    continue
                case .rejected:
                    applyRejection(
                        result,
                        to: &snapshot.operations[completedIndex],
                        now: now,
                        summary: &summary
                    )
                }
            } catch {
                guard let failedIndex = snapshot.operations.firstIndex(where: { $0.id == operationID }) else {
                    continue
                }

                snapshot.operations[failedIndex].markFailed(
                    message: error.localizedDescription,
                    nextRetryAt: now.addingTimeInterval(retryPolicy.retryDelay),
                    at: now
                )
                summary.failedCount += 1
            }

            snapshot.updatedAt = now
            try persist(snapshot, now: now)
        }

        return summary
    }

    private func applyRejection(
        _ result: SyncOperationServerResult,
        to operation: inout SyncOperation,
        now: Date,
        summary: inout SyncRunSummary
    ) {
        if result.errorCode == .financialConflict {
            operation.markNeedsReview(
                reason: .financialConflict,
                message: "Financial conflict requires review before retrying.",
                result: result,
                at: now
            )
            summary.needsReviewCount += 1
            return
        }

        let message = result.errorCode?.rawValue ?? "sync_rejected"
        operation.markFailed(message: message, nextRetryAt: nil, at: now)
        summary.failedCount += 1
    }

    private func readSnapshot(defaultUpdatedAt: Date) throws -> SyncOutboxSnapshot {
        try outboxStore.readSyncOutbox() ?? SyncOutboxSnapshot(updatedAt: defaultUpdatedAt)
    }

    private func persist(
        _ snapshot: SyncOutboxSnapshot,
        now: Date,
        lastSuccessfulSyncAt: Date? = nil
    ) throws {
        try outboxStore.saveSyncOutbox(snapshot)

        let previousMetadata = try outboxStore.readSyncMetadata()
        try outboxStore.saveSyncMetadata(
            snapshot.metadataSnapshot(
                lastSuccessfulSyncAt: lastSuccessfulSyncAt ?? previousMetadata?.lastSuccessfulSyncAt,
                updatedAt: now
            )
        )
    }
}

private extension SyncOutboxSnapshot {
    func metadataSnapshot(
        lastSuccessfulSyncAt: Date?,
        updatedAt: Date
    ) -> SyncMetadataSnapshot {
        SyncMetadataSnapshot(
            lastSuccessfulSyncAt: lastSuccessfulSyncAt,
            pendingMutationCount: operations.filter { $0.state == .queued || $0.state == .syncing }.count,
            failedMutationCount: operations.filter { $0.state == .failed || $0.state == .needsReview }.count,
            records: operations.map(\.metadataRecord),
            updatedAt: updatedAt
        )
    }
}

private extension SyncOperation {
    var metadataRecord: SyncRecordMetadata {
        SyncRecordMetadata(
            id: id,
            entityKind: entityKind,
            entityID: entityID,
            state: state.recordState,
            updatedAt: updatedAt,
            lastErrorMessage: lastErrorMessage
        )
    }
}

private extension SyncOperationState {
    var recordState: SyncRecordState {
        switch self {
        case .queued:
            return .queued
        case .syncing:
            return .syncing
        case .synced:
            return .synced
        case .failed:
            return .failed
        case .needsReview:
            return .needsReview
        }
    }
}
