//
//  Created by Jerel Walters on 6/24/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import StorageModule
import XCTest
@testable import HaulMate

@MainActor
final class HaulMateLocalStorageRepositoryTests: XCTestCase {
    func testStorageTypeInitializerCanUseFileStorageForLocalState() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.haulmate.repository-storage-type-tests.\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let repository = try HaulMateLocalStorageRepository(
            storageType: .fileStorage,
            fileDirectoryURL: directoryURL
        )
        let snapshot = ActiveWorkflowSnapshot(
            activeLoadID: nil,
            navigationSnapshot: NavigationSnapshot(
                selectedTab: .dashboard,
                dashboardPath: [],
                loadsPath: [],
                settingsPath: [],
                presentedSheet: nil
            ),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        try repository.saveActiveWorkflow(snapshot)

        XCTAssertEqual(try repository.readActiveWorkflow(), snapshot)
        let storedFiles = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(
            storedFiles.count,
            1
        )
    }

    func testProfileRoundTripPersistsCurrentDTOWithoutLogoBytes() throws {
        let storage = MemoryStorage()
        let repository = HaulMateLocalStorageRepository(storage: storage)
        var businessProfile = BusinessProfileDraft.validPilotProfile
        businessProfile.setLogoImageData(Data([0x01, 0x02, 0x03]))
        let profile = ProfileSnapshot(
            businessProfile: businessProfile,
            truckCostProfile: .figmaBaseline
        )

        try repository.saveProfile(profile)

        let restored = try repository.readProfile()
        XCTAssertEqual(restored?.businessProfile?.legalName, "Walters Logistics LLC")
        XCTAssertEqual(restored?.businessProfile?.logoFilename, "business-logo")
        XCTAssertNil(restored?.businessProfile?.logoImageData)
        XCTAssertEqual(restored?.truckCostProfile, .figmaBaseline)

        let storedProfile = try XCTUnwrap(
            try storage.read(StoredProfile.self, for: HaulMateStorageKeys.profile)
        )
        guard case .v2 = storedProfile else {
            return XCTFail("Expected current profile DTO.")
        }
    }

    func testLegacyProfileV1MigratesToCurrentDTOAfterRead() throws {
        let storage = MemoryStorage()
        let repository = HaulMateLocalStorageRepository(storage: storage)
        try storage.save(
            StoredProfile.v1(
                StoredProfileV1(
                    legalName: "Walters Logistics LLC",
                    displayName: "Walters Logistics",
                    mailingAddress: "123 Pilot Way, Detroit, MI 48201",
                    phone: "313-555-0148",
                    invoiceEmail: "billing@example.com",
                    invoicePrefix: "HM",
                    paymentTermsDays: 30,
                    logoFilename: "business-logo",
                    usesFactoring: true,
                    factoringCompanyName: "Pilot Factoring",
                    factoringRemittanceDetails: "ACH ending 4242"
                )
            ),
            for: HaulMateStorageKeys.profile
        )

        let migrated = try repository.readProfile()

        XCTAssertEqual(migrated?.businessProfile?.displayName, "Walters Logistics")
        XCTAssertEqual(migrated?.businessProfile?.usesFactoring, true)
        XCTAssertNil(migrated?.truckCostProfile)

        let storedProfile = try XCTUnwrap(
            try storage.read(StoredProfile.self, for: HaulMateStorageKeys.profile)
        )
        guard case .v2(let storedV2) = storedProfile else {
            return XCTFail("Expected migrated current profile DTO.")
        }
        XCTAssertEqual(storedV2.businessProfile?.legalName, "Walters Logistics LLC")
        XCTAssertNil(storedV2.truckCostProfile)
    }

    func testActiveWorkflowRoundTripPersistsNavigationAndActiveLoad() throws {
        let repository = HaulMateLocalStorageRepository(storage: MemoryStorage())
        let loadID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let snapshot = ActiveWorkflowSnapshot(
            activeLoadID: loadID,
            navigationSnapshot: NavigationSnapshot(
                selectedTab: .loads,
                dashboardPath: [],
                loadsPath: [.load(id: loadID)],
                settingsPath: [],
                presentedSheet: .newLoad
            ),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        try repository.saveActiveWorkflow(snapshot)

        XCTAssertEqual(try repository.readActiveWorkflow(), snapshot)

        try repository.deleteActiveWorkflow()

        XCTAssertNil(try repository.readActiveWorkflow())
    }

    func testRecentDocumentsRoundTripStoresMetadataOnly() throws {
        let repository = HaulMateLocalStorageRepository(storage: MemoryStorage())
        let document = RecentDocumentReference(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            loadID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            kind: .proofOfDelivery,
            fileName: "pod.pdf",
            contentType: "application/pdf",
            byteCount: 82_400,
            localFileURL: URL(fileURLWithPath: "/private/var/mobile/Containers/Data/pod.pdf"),
            remoteObjectKey: "user/load/document",
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let snapshot = RecentDocumentsSnapshot(
            documents: [document],
            updatedAt: Date(timeIntervalSince1970: 2_100)
        )

        try repository.saveRecentDocuments(snapshot)

        XCTAssertEqual(try repository.readRecentDocuments(), snapshot)

        try repository.deleteRecentDocuments()

        XCTAssertNil(try repository.readRecentDocuments())
    }

    func testSyncMetadataRoundTripPersistsPerRecordState() throws {
        let repository = HaulMateLocalStorageRepository(storage: MemoryStorage())
        let record = SyncRecordMetadata(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            entityKind: .document,
            entityID: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            state: .failed,
            updatedAt: Date(timeIntervalSince1970: 3_000),
            lastErrorMessage: "Upload failed"
        )
        let snapshot = SyncMetadataSnapshot(
            lastSuccessfulSyncAt: Date(timeIntervalSince1970: 2_900),
            pendingMutationCount: 2,
            failedMutationCount: 1,
            records: [record],
            updatedAt: Date(timeIntervalSince1970: 3_100)
        )

        try repository.saveSyncMetadata(snapshot)

        XCTAssertEqual(try repository.readSyncMetadata(), snapshot)

        try repository.deleteSyncMetadata()

        XCTAssertNil(try repository.readSyncMetadata())
    }

    func testSyncOutboxRoundTripPersistsQueuedOperations() throws {
        let repository = HaulMateLocalStorageRepository(storage: MemoryStorage())
        let operation = try SyncOperation.loadUpsert(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            idempotencyKey: "load:55555555-5555-5555-5555-555555555555:v1",
            payload: LoadSyncPayload(
                loadID: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                customerID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
                referenceNumber: "RC-4182",
                status: .accepted,
                lineHaulRate: Decimal(1_850),
                loadedMiles: Decimal(540)
            ),
            createdAt: Date(timeIntervalSince1970: 3_200)
        )
        let snapshot = SyncOutboxSnapshot(
            operations: [operation],
            updatedAt: Date(timeIntervalSince1970: 3_300)
        )

        try repository.saveSyncOutbox(snapshot)

        XCTAssertEqual(try repository.readSyncOutbox(), snapshot)

        try repository.deleteSyncOutbox()

        XCTAssertNil(try repository.readSyncOutbox())
    }

    func testDeleteAccountScopedDataClearsEveryLocalAccountKey() throws {
        let repository = HaulMateLocalStorageRepository(storage: MemoryStorage())
        let loadID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

        try repository.saveActiveWorkflow(
            ActiveWorkflowSnapshot(
                activeLoadID: loadID,
                navigationSnapshot: NavigationSnapshot(
                    selectedTab: .loads,
                    dashboardPath: [],
                    loadsPath: [.load(id: loadID)],
                    settingsPath: [],
                    presentedSheet: nil
                ),
                updatedAt: Date(timeIntervalSince1970: 1_000)
            )
        )
        try repository.saveProfile(
            ProfileSnapshot(
                businessProfile: .validPilotProfile,
                truckCostProfile: .figmaBaseline
            )
        )
        try repository.saveRecentDocuments(
            RecentDocumentsSnapshot(
                documents: [
                    RecentDocumentReference(
                        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                        loadID: loadID,
                        kind: .proofOfDelivery,
                        fileName: "pod.pdf",
                        contentType: "application/pdf",
                        byteCount: 82_400,
                        updatedAt: Date(timeIntervalSince1970: 2_000)
                    )
                ],
                updatedAt: Date(timeIntervalSince1970: 2_100)
            )
        )
        try repository.saveSyncOutbox(
            SyncOutboxSnapshot(
                operations: [
                    try SyncOperation.loadUpsert(
                        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                        idempotencyKey: "load:\(loadID.uuidString):v1",
                        payload: LoadSyncPayload(
                            loadID: loadID,
                            customerID: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                            referenceNumber: "RC-4182",
                            status: .accepted,
                            lineHaulRate: Decimal(1_850),
                            loadedMiles: Decimal(540)
                        ),
                        createdAt: Date(timeIntervalSince1970: 2_500)
                    )
                ],
                updatedAt: Date(timeIntervalSince1970: 2_600)
            )
        )
        try repository.saveSyncMetadata(
            SyncMetadataSnapshot(
                pendingMutationCount: 1,
                failedMutationCount: 0,
                records: [
                    SyncRecordMetadata(
                        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                        entityKind: .load,
                        entityID: loadID,
                        state: .localOnly,
                        updatedAt: Date(timeIntervalSince1970: 3_000)
                    )
                ],
                updatedAt: Date(timeIntervalSince1970: 3_100)
            )
        )

        try repository.deleteAccountScopedData()

        XCTAssertNil(try repository.readActiveWorkflow())
        XCTAssertNil(try repository.readProfile())
        XCTAssertNil(try repository.readRecentDocuments())
        XCTAssertNil(try repository.readSyncOutbox())
        XCTAssertNil(try repository.readSyncMetadata())
    }

    func testAccountScopedCleanerClearsRepositoryStateAndRawDocumentFiles() async throws {
        let repository = HaulMateLocalStorageRepository(storage: MemoryStorage())
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.haulmate.account-cleaner-tests.\(UUID().uuidString)", isDirectory: true)
        let sourceDirectoryURL = directoryURL.appendingPathComponent("Source", isDirectory: true)
        let documentDirectoryURL = directoryURL.appendingPathComponent("Documents", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        try FileManager.default.createDirectory(
            at: sourceDirectoryURL,
            withIntermediateDirectories: true
        )
        let sourceURL = sourceDirectoryURL.appendingPathComponent("pod.pdf")
        try Data("proof-of-delivery".utf8).write(to: sourceURL)
        let documentStore = LocalDocumentFileStore(directoryURL: documentDirectoryURL)
        let storedDocument = try documentStore.persistDocument(
            from: sourceURL,
            documentID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            preferredFileName: "pod.pdf"
        )
        try repository.saveRecentDocuments(
            RecentDocumentsSnapshot(
                documents: [
                    RecentDocumentReference(
                        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                        loadID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                        kind: .proofOfDelivery,
                        fileName: "pod.pdf",
                        contentType: "application/pdf",
                        byteCount: storedDocument.byteCount,
                        sha256Hex: storedDocument.sha256Hex,
                        localFileURL: storedDocument.fileURL,
                        updatedAt: Date(timeIntervalSince1970: 2_000)
                    )
                ],
                updatedAt: Date(timeIntervalSince1970: 2_100)
            )
        )
        let cleaner = HaulMateAccountScopedDataCleaner(
            localStorageRepository: { repository },
            documentFileStore: { documentStore }
        )

        try await cleaner.clearAccountScopedData()

        XCTAssertNil(try repository.readRecentDocuments())
        XCTAssertFalse(FileManager.default.fileExists(atPath: storedDocument.fileURL.path))
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

private extension BusinessProfileDraft {
    static let validPilotProfile = BusinessProfileDraft(
        legalName: "Walters Logistics LLC",
        displayName: "Walters Logistics",
        mailingAddress: "123 Pilot Way, Detroit, MI 48201",
        phone: "313-555-0148",
        invoiceEmail: "billing@example.com",
        invoicePrefix: "HM",
        paymentTermsDays: 30
    )
}
