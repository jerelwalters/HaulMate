//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

enum StoredProfile: Codable, Equatable {
    case v1(StoredProfileV1)
    case v2(StoredProfileV2)

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)

        switch schemaVersion {
        case 1:
            self = .v1(try StoredProfileV1(from: decoder))
        case 2:
            self = .v2(try StoredProfileV2(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported profile schema version \(schemaVersion)."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .v1(let storedProfile):
            try storedProfile.encode(to: encoder)
        case .v2(let storedProfile):
            try storedProfile.encode(to: encoder)
        }
    }

    static func current(from snapshot: ProfileSnapshot) -> StoredProfile {
        .v2(StoredProfileV2(snapshot: snapshot))
    }

    var snapshot: ProfileSnapshot {
        switch self {
        case .v1(let storedProfile):
            return storedProfile.snapshot
        case .v2(let storedProfile):
            return storedProfile.snapshot
        }
    }

    var requiresMigration: Bool {
        if case .v1 = self {
            return true
        }

        return false
    }
}

struct StoredProfileV1: Codable, Equatable {
    let schemaVersion: Int
    var legalName: String
    var displayName: String
    var mailingAddress: String
    var phone: String
    var invoiceEmail: String
    var invoicePrefix: String
    var paymentTermsDays: Int
    var logoFilename: String
    var usesFactoring: Bool
    var factoringCompanyName: String
    var factoringRemittanceDetails: String

    init(
        schemaVersion: Int = 1,
        legalName: String,
        displayName: String,
        mailingAddress: String,
        phone: String,
        invoiceEmail: String,
        invoicePrefix: String,
        paymentTermsDays: Int,
        logoFilename: String,
        usesFactoring: Bool,
        factoringCompanyName: String,
        factoringRemittanceDetails: String
    ) {
        self.schemaVersion = schemaVersion
        self.legalName = legalName
        self.displayName = displayName
        self.mailingAddress = mailingAddress
        self.phone = phone
        self.invoiceEmail = invoiceEmail
        self.invoicePrefix = invoicePrefix
        self.paymentTermsDays = paymentTermsDays
        self.logoFilename = logoFilename
        self.usesFactoring = usesFactoring
        self.factoringCompanyName = factoringCompanyName
        self.factoringRemittanceDetails = factoringRemittanceDetails
    }

    var snapshot: ProfileSnapshot {
        ProfileSnapshot(
            businessProfile: BusinessProfileDraft(
                legalName: legalName,
                displayName: displayName,
                mailingAddress: mailingAddress,
                phone: phone,
                invoiceEmail: invoiceEmail,
                invoicePrefix: invoicePrefix,
                paymentTermsDays: paymentTermsDays,
                logoFilename: logoFilename,
                logoImageData: nil,
                usesFactoring: usesFactoring,
                factoringCompanyName: factoringCompanyName,
                factoringRemittanceDetails: factoringRemittanceDetails
            )
        )
    }
}

struct StoredProfileV2: Codable, Equatable {
    let schemaVersion: Int
    var businessProfile: StoredBusinessProfileV1?
    var truckCostProfile: StoredTruckCostProfileV1?

    init(
        schemaVersion: Int = 2,
        businessProfile: StoredBusinessProfileV1?,
        truckCostProfile: StoredTruckCostProfileV1?
    ) {
        self.schemaVersion = schemaVersion
        self.businessProfile = businessProfile
        self.truckCostProfile = truckCostProfile
    }

    init(snapshot: ProfileSnapshot) {
        self.init(
            businessProfile: snapshot.businessProfile.map(StoredBusinessProfileV1.init),
            truckCostProfile: snapshot.truckCostProfile.map(StoredTruckCostProfileV1.init)
        )
    }

    var snapshot: ProfileSnapshot {
        ProfileSnapshot(
            businessProfile: businessProfile?.draft,
            truckCostProfile: truckCostProfile?.draft
        )
    }
}

struct StoredBusinessProfileV1: Codable, Equatable {
    var legalName: String
    var displayName: String
    var mailingAddress: String
    var phone: String
    var invoiceEmail: String
    var invoicePrefix: String
    var paymentTermsDays: Int
    var logoFilename: String
    var usesFactoring: Bool
    var factoringCompanyName: String
    var factoringRemittanceDetails: String

    init(draft: BusinessProfileDraft) {
        legalName = draft.legalName
        displayName = draft.displayName
        mailingAddress = draft.mailingAddress
        phone = draft.phone
        invoiceEmail = draft.invoiceEmail
        invoicePrefix = draft.invoicePrefix
        paymentTermsDays = draft.paymentTermsDays
        logoFilename = draft.logoFilename
        usesFactoring = draft.usesFactoring
        factoringCompanyName = draft.factoringCompanyName
        factoringRemittanceDetails = draft.factoringRemittanceDetails
    }

    var draft: BusinessProfileDraft {
        BusinessProfileDraft(
            legalName: legalName,
            displayName: displayName,
            mailingAddress: mailingAddress,
            phone: phone,
            invoiceEmail: invoiceEmail,
            invoicePrefix: invoicePrefix,
            paymentTermsDays: paymentTermsDays,
            logoFilename: logoFilename,
            logoImageData: nil,
            usesFactoring: usesFactoring,
            factoringCompanyName: factoringCompanyName,
            factoringRemittanceDetails: factoringRemittanceDetails
        )
    }
}

struct StoredTruckCostProfileV1: Codable, Equatable {
    var equipmentName: String
    var fuelEconomyMPG: String
    var fuelPricePerGallon: String
    var maintenanceReservePerMile: String
    var monthlyFixedCosts: String
    var estimatedWorkingMiles: String
    var dispatchFeePercent: String
    var factoringFeePercent: String
    var profitTargetPercent: String

    init(draft: TruckCostProfileDraft) {
        equipmentName = draft.equipmentName
        fuelEconomyMPG = draft.fuelEconomyMPG
        fuelPricePerGallon = draft.fuelPricePerGallon
        maintenanceReservePerMile = draft.maintenanceReservePerMile
        monthlyFixedCosts = draft.monthlyFixedCosts
        estimatedWorkingMiles = draft.estimatedWorkingMiles
        dispatchFeePercent = draft.dispatchFeePercent
        factoringFeePercent = draft.factoringFeePercent
        profitTargetPercent = draft.profitTargetPercent
    }

    var draft: TruckCostProfileDraft {
        TruckCostProfileDraft(
            equipmentName: equipmentName,
            fuelEconomyMPG: fuelEconomyMPG,
            fuelPricePerGallon: fuelPricePerGallon,
            maintenanceReservePerMile: maintenanceReservePerMile,
            monthlyFixedCosts: monthlyFixedCosts,
            estimatedWorkingMiles: estimatedWorkingMiles,
            dispatchFeePercent: dispatchFeePercent,
            factoringFeePercent: factoringFeePercent,
            profitTargetPercent: profitTargetPercent
        )
    }
}

struct StoredActiveWorkflow: Codable, Equatable {
    let schemaVersion: Int
    var activeLoadID: UUID?
    var navigationSnapshot: NavigationSnapshot
    var updatedAt: Date

    init(
        schemaVersion: Int = 1,
        activeLoadID: UUID?,
        navigationSnapshot: NavigationSnapshot,
        updatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.activeLoadID = activeLoadID
        self.navigationSnapshot = navigationSnapshot
        self.updatedAt = updatedAt
    }

    init(snapshot: ActiveWorkflowSnapshot) {
        self.init(
            activeLoadID: snapshot.activeLoadID,
            navigationSnapshot: snapshot.navigationSnapshot,
            updatedAt: snapshot.updatedAt
        )
    }

    var snapshot: ActiveWorkflowSnapshot {
        ActiveWorkflowSnapshot(
            activeLoadID: activeLoadID,
            navigationSnapshot: navigationSnapshot,
            updatedAt: updatedAt
        )
    }
}

struct StoredRecentDocuments: Codable, Equatable {
    let schemaVersion: Int
    var documents: [StoredRecentDocumentV1]
    var updatedAt: Date

    init(
        schemaVersion: Int = 1,
        documents: [StoredRecentDocumentV1],
        updatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.documents = documents
        self.updatedAt = updatedAt
    }

    init(snapshot: RecentDocumentsSnapshot) {
        self.init(
            documents: snapshot.documents.map(StoredRecentDocumentV1.init),
            updatedAt: snapshot.updatedAt
        )
    }

    var snapshot: RecentDocumentsSnapshot {
        RecentDocumentsSnapshot(
            documents: documents.map(\.document),
            updatedAt: updatedAt
        )
    }
}

struct StoredRecentDocumentV1: Codable, Equatable {
    var id: UUID
    var loadID: UUID?
    var kind: RecentDocumentKind
    var fileName: String
    var contentType: String
    var byteCount: Int64
    var localFileURL: URL?
    var remoteObjectKey: String?
    var updatedAt: Date

    init(document: RecentDocumentReference) {
        id = document.id
        loadID = document.loadID
        kind = document.kind
        fileName = document.fileName
        contentType = document.contentType
        byteCount = document.byteCount
        localFileURL = document.localFileURL
        remoteObjectKey = document.remoteObjectKey
        updatedAt = document.updatedAt
    }

    var document: RecentDocumentReference {
        RecentDocumentReference(
            id: id,
            loadID: loadID,
            kind: kind,
            fileName: fileName,
            contentType: contentType,
            byteCount: byteCount,
            localFileURL: localFileURL,
            remoteObjectKey: remoteObjectKey,
            updatedAt: updatedAt
        )
    }
}

struct StoredSyncMetadata: Codable, Equatable {
    let schemaVersion: Int
    var lastSuccessfulSyncAt: Date?
    var pendingMutationCount: Int
    var failedMutationCount: Int
    var records: [StoredSyncRecordMetadataV1]
    var updatedAt: Date

    init(
        schemaVersion: Int = 1,
        lastSuccessfulSyncAt: Date?,
        pendingMutationCount: Int,
        failedMutationCount: Int,
        records: [StoredSyncRecordMetadataV1],
        updatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.lastSuccessfulSyncAt = lastSuccessfulSyncAt
        self.pendingMutationCount = pendingMutationCount
        self.failedMutationCount = failedMutationCount
        self.records = records
        self.updatedAt = updatedAt
    }

    init(snapshot: SyncMetadataSnapshot) {
        self.init(
            lastSuccessfulSyncAt: snapshot.lastSuccessfulSyncAt,
            pendingMutationCount: snapshot.pendingMutationCount,
            failedMutationCount: snapshot.failedMutationCount,
            records: snapshot.records.map(StoredSyncRecordMetadataV1.init),
            updatedAt: snapshot.updatedAt
        )
    }

    var snapshot: SyncMetadataSnapshot {
        SyncMetadataSnapshot(
            lastSuccessfulSyncAt: lastSuccessfulSyncAt,
            pendingMutationCount: pendingMutationCount,
            failedMutationCount: failedMutationCount,
            records: records.map(\.record),
            updatedAt: updatedAt
        )
    }
}

struct StoredSyncRecordMetadataV1: Codable, Equatable {
    var id: UUID
    var entityKind: SyncRecordEntityKind
    var entityID: UUID
    var state: SyncRecordState
    var updatedAt: Date
    var lastErrorMessage: String?

    init(record: SyncRecordMetadata) {
        id = record.id
        entityKind = record.entityKind
        entityID = record.entityID
        state = record.state
        updatedAt = record.updatedAt
        lastErrorMessage = record.lastErrorMessage
    }

    var record: SyncRecordMetadata {
        SyncRecordMetadata(
            id: id,
            entityKind: entityKind,
            entityID: entityID,
            state: state,
            updatedAt: updatedAt,
            lastErrorMessage: lastErrorMessage
        )
    }
}
