//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

struct ActiveWorkflowSnapshot: Equatable, Sendable {
    var activeLoadID: UUID?
    var navigationSnapshot: NavigationSnapshot
    var updatedAt: Date

    init(
        activeLoadID: UUID? = nil,
        navigationSnapshot: NavigationSnapshot = NavigationSnapshot(),
        updatedAt: Date
    ) {
        self.activeLoadID = activeLoadID
        self.navigationSnapshot = navigationSnapshot
        self.updatedAt = updatedAt
    }
}

struct ProfileSnapshot: Equatable, Sendable {
    var businessProfile: BusinessProfileDraft?
    var truckCostProfile: TruckCostProfileDraft?

    init(
        businessProfile: BusinessProfileDraft? = nil,
        truckCostProfile: TruckCostProfileDraft? = nil
    ) {
        self.businessProfile = businessProfile
        self.truckCostProfile = truckCostProfile
    }
}

struct RecentDocumentsSnapshot: Equatable, Sendable {
    var documents: [RecentDocumentReference]
    var updatedAt: Date

    init(
        documents: [RecentDocumentReference] = [],
        updatedAt: Date
    ) {
        self.documents = documents
        self.updatedAt = updatedAt
    }
}

struct RecentDocumentReference: Equatable, Identifiable, Sendable {
    let id: UUID
    var loadID: UUID?
    var kind: RecentDocumentKind
    var fileName: String
    var contentType: String
    var byteCount: Int64
    var localFileURL: URL?
    var remoteObjectKey: String?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        loadID: UUID? = nil,
        kind: RecentDocumentKind,
        fileName: String,
        contentType: String,
        byteCount: Int64,
        localFileURL: URL? = nil,
        remoteObjectKey: String? = nil,
        updatedAt: Date
    ) {
        self.id = id
        self.loadID = loadID
        self.kind = kind
        self.fileName = fileName
        self.contentType = contentType
        self.byteCount = byteCount
        self.localFileURL = localFileURL
        self.remoteObjectKey = remoteObjectKey
        self.updatedAt = updatedAt
    }
}

enum RecentDocumentKind: String, Codable, Sendable {
    case rateConfirmation
    case billOfLading
    case proofOfDelivery
    case receipt
    case lumperReceipt
    case invoice
    case otherEvidence
}

struct SyncMetadataSnapshot: Equatable, Sendable {
    var lastSuccessfulSyncAt: Date?
    var pendingMutationCount: Int
    var failedMutationCount: Int
    var records: [SyncRecordMetadata]
    var updatedAt: Date

    init(
        lastSuccessfulSyncAt: Date? = nil,
        pendingMutationCount: Int = 0,
        failedMutationCount: Int = 0,
        records: [SyncRecordMetadata] = [],
        updatedAt: Date
    ) {
        self.lastSuccessfulSyncAt = lastSuccessfulSyncAt
        self.pendingMutationCount = pendingMutationCount
        self.failedMutationCount = failedMutationCount
        self.records = records
        self.updatedAt = updatedAt
    }
}

struct SyncRecordMetadata: Equatable, Identifiable, Sendable {
    let id: UUID
    var entityKind: SyncRecordEntityKind
    var entityID: UUID
    var state: SyncRecordState
    var updatedAt: Date
    var lastErrorMessage: String?

    init(
        id: UUID = UUID(),
        entityKind: SyncRecordEntityKind,
        entityID: UUID,
        state: SyncRecordState,
        updatedAt: Date,
        lastErrorMessage: String? = nil
    ) {
        self.id = id
        self.entityKind = entityKind
        self.entityID = entityID
        self.state = state
        self.updatedAt = updatedAt
        self.lastErrorMessage = lastErrorMessage
    }
}

enum SyncRecordEntityKind: String, Codable, Sendable {
    case profile
    case load
    case document
    case invoice
    case payment
    case share
}

enum SyncRecordState: String, Codable, Sendable {
    case localOnly
    case queued
    case syncing
    case synced
    case failed
    case needsReview
}
