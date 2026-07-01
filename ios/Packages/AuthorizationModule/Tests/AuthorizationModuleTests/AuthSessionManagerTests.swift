//
//  Created by Jerel Walters on 6/30/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
@testable import AuthorizationModule

final class AuthSessionManagerTests: XCTestCase {
    func testRestoreSessionReturnsStoredUnexpiredSession() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let session = AuthSession.fixture(expiresAt: now.addingTimeInterval(60))
        let store = MemoryAuthSessionStore(session: session)
        let manager = AuthSessionManager(
            sessionStore: store,
            businessProfileStore: MemoryBusinessProfileStore(),
            accountDataCleaner: CapturingAccountDataCleaner(),
            now: { now }
        )

        let restoredUser = try await manager.restoreSession()

        XCTAssertEqual(restoredUser, session.user)
    }

    func testRestoreSessionRefreshesExpiredSessionAndPersistsReplacement() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let expiredSession = AuthSession.fixture(expiresAt: now.addingTimeInterval(-1))
        let refreshedSession = AuthSession.fixture(
            user: SessionUser(id: expiredSession.user.id, displayName: "Refreshed"),
            expiresAt: now.addingTimeInterval(600)
        )
        let store = MemoryAuthSessionStore(session: expiredSession)
        let refresher = CapturingAuthSessionRefresher(refreshedSession: refreshedSession)
        let manager = AuthSessionManager(
            sessionStore: store,
            businessProfileStore: MemoryBusinessProfileStore(),
            sessionRefresher: refresher,
            accountDataCleaner: CapturingAccountDataCleaner(),
            now: { now }
        )

        let restoredUser = try await manager.restoreSession()

        XCTAssertEqual(restoredUser, refreshedSession.user)
        let persistedSession = try await store.readSession()
        let capturedSession = await refresher.capturedSession()
        XCTAssertEqual(persistedSession, refreshedSession)
        XCTAssertEqual(capturedSession, expiredSession)
    }

    func testRestoreSessionDeletesExpiredSessionWhenRefreshFailsWithoutClearingLocalData() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let expiredSession = AuthSession.fixture(expiresAt: now.addingTimeInterval(-1))
        let store = MemoryAuthSessionStore(session: expiredSession)
        let cleaner = CapturingAccountDataCleaner()
        let manager = AuthSessionManager(
            sessionStore: store,
            businessProfileStore: MemoryBusinessProfileStore(),
            sessionRefresher: CapturingAuthSessionRefresher(refreshedSession: nil),
            accountDataCleaner: cleaner,
            now: { now }
        )

        let restoredUser = try await manager.restoreSession()

        XCTAssertNil(restoredUser)
        let storedSession = try await store.readSession()
        let storedUserID = try await store.readSessionUserID()
        let clearCount = await cleaner.clearCount()
        XCTAssertNil(storedSession)
        XCTAssertEqual(storedUserID, expiredSession.user.id)
        XCTAssertEqual(clearCount, 0)
    }

    func testSignInPersistsSessionMaterial() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let store = MemoryAuthSessionStore()
        let manager = AuthSessionManager(
            sessionStore: store,
            businessProfileStore: MemoryBusinessProfileStore(),
            accountDataCleaner: CapturingAccountDataCleaner(),
            now: { now }
        )

        let user = try await manager.signIn(
            request: SignInRequest(
                email: "driver@example.com",
                password: "password123"
            )
        )

        let savedSession = await store.storedSession()
        let storedSession = try XCTUnwrap(savedSession)
        XCTAssertEqual(storedSession.user, user)
        XCTAssertFalse(storedSession.accessToken.isEmpty)
        XCTAssertFalse(storedSession.refreshToken.isEmpty)
        XCTAssertEqual(storedSession.savedAt, now)
        XCTAssertGreaterThan(storedSession.expiresAt, now)
    }

    func testSignUpPersistsNormalizedBusinessProfile() async throws {
        let store = MemoryAuthSessionStore()
        let businessProfileStore = MemoryBusinessProfileStore()
        let manager = AuthSessionManager(
            sessionStore: store,
            businessProfileStore: businessProfileStore,
            accountDataCleaner: CapturingAccountDataCleaner()
        )
        var profile = BusinessProfileDraft.validPilotProfile
        profile.legalName = "  Walters Logistics LLC  "
        profile.invoicePrefix = " HM "

        _ = try await manager.signUp(
            request: SignUpRequest(
                email: "driver@example.com",
                password: "password123",
                businessProfile: profile
            )
        )

        let storedProfile = await businessProfileStore.storedBusinessProfile()
        let currentProfile = try await manager.currentBusinessProfile()
        XCTAssertEqual(storedProfile, profile.normalized)
        XCTAssertEqual(currentProfile, profile.normalized)
    }

    func testUpdateBusinessProfilePersistsNormalizedProfileForCurrentUser() async throws {
        let store = MemoryAuthSessionStore()
        let businessProfileStore = MemoryBusinessProfileStore()
        let manager = AuthSessionManager(
            sessionStore: store,
            businessProfileStore: businessProfileStore,
            accountDataCleaner: CapturingAccountDataCleaner()
        )
        _ = try await manager.signIn(
            request: SignInRequest(
                email: "driver@example.com",
                password: "password123"
            )
        )
        var profile = BusinessProfileDraft.validPilotProfile
        profile.displayName = "  Walters Freight  "
        profile.factoringCompanyName = "  Pilot Factoring  "

        let updatedProfile = try await manager.updateBusinessProfile(profile)

        let storedProfile = await businessProfileStore.storedBusinessProfile()
        XCTAssertEqual(updatedProfile, profile.normalized)
        XCTAssertEqual(storedProfile, profile.normalized)
    }

    func testCurrentBusinessProfileDoesNotReadStoredProfileWithoutCurrentUser() async throws {
        let manager = AuthSessionManager(
            sessionStore: MemoryAuthSessionStore(),
            businessProfileStore: MemoryBusinessProfileStore(profile: .validPilotProfile),
            accountDataCleaner: CapturingAccountDataCleaner()
        )

        let profile = try await manager.currentBusinessProfile()

        XCTAssertNil(profile)
    }

    func testSignInClearsAccountScopedDataWhenReplacingAnotherStoredAccount() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let previousSession = AuthSession.fixture(expiresAt: now.addingTimeInterval(600))
        let store = MemoryAuthSessionStore(session: previousSession)
        let cleaner = CapturingAccountDataCleaner()
        let manager = AuthSessionManager(
            sessionStore: store,
            businessProfileStore: MemoryBusinessProfileStore(),
            accountDataCleaner: cleaner,
            now: { now }
        )

        _ = try await manager.signIn(
            request: SignInRequest(
                email: "new-driver@example.com",
                password: "password123"
            )
        )

        let savedSession = await store.storedSession()
        let storedSession = try XCTUnwrap(savedSession)
        let clearCount = await cleaner.clearCount()
        XCTAssertNotEqual(storedSession.user.id, previousSession.user.id)
        XCTAssertEqual(clearCount, 1)
    }

    func testSignInClearsAccountScopedDataWhenOnlyPreviousUserMarkerRemains() async throws {
        let previousUserID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let store = MemoryAuthSessionStore(sessionUserID: previousUserID)
        let cleaner = CapturingAccountDataCleaner()
        let manager = AuthSessionManager(
            sessionStore: store,
            businessProfileStore: MemoryBusinessProfileStore(),
            accountDataCleaner: cleaner
        )

        _ = try await manager.signIn(
            request: SignInRequest(
                email: "new-driver@example.com",
                password: "password123"
            )
        )

        let clearCount = await cleaner.clearCount()
        XCTAssertEqual(clearCount, 1)
    }

    func testSignOutDeletesSessionAndClearsAccountScopedData() async throws {
        let session = AuthSession.fixture()
        let store = MemoryAuthSessionStore(session: session)
        let cleaner = CapturingAccountDataCleaner()
        let manager = AuthSessionManager(
            sessionStore: store,
            businessProfileStore: MemoryBusinessProfileStore(),
            accountDataCleaner: cleaner
        )

        try await manager.signOut()

        let storedSession = try await store.readSession()
        let storedUserID = try await store.readSessionUserID()
        let clearCount = await cleaner.clearCount()
        XCTAssertNil(storedSession)
        XCTAssertNil(storedUserID)
        XCTAssertEqual(clearCount, 1)
    }
}

private actor MemoryAuthSessionStore: AuthSessionStoring {
    private var session: AuthSession?
    private var sessionUserID: UUID?

    init(
        session: AuthSession? = nil,
        sessionUserID: UUID? = nil
    ) {
        self.session = session
        self.sessionUserID = session?.user.id ?? sessionUserID
    }

    func readSession() async throws -> AuthSession? {
        session
    }

    func readSessionUserID() async throws -> UUID? {
        sessionUserID
    }

    func saveSession(_ session: AuthSession) async throws {
        self.session = session
        sessionUserID = session.user.id
    }

    func deleteSession() async throws {
        session = nil
    }

    func deleteSessionUserID() async throws {
        sessionUserID = nil
    }

    func storedSession() -> AuthSession? {
        session
    }
}

private actor MemoryBusinessProfileStore: BusinessProfileStoring {
    private var profile: BusinessProfileDraft?

    init(profile: BusinessProfileDraft? = nil) {
        self.profile = profile
    }

    func readBusinessProfile() async throws -> BusinessProfileDraft? {
        profile
    }

    func saveBusinessProfile(_ profile: BusinessProfileDraft) async throws {
        self.profile = profile
    }

    func storedBusinessProfile() -> BusinessProfileDraft? {
        profile
    }
}

private actor CapturingAuthSessionRefresher: AuthSessionRefreshing {
    private let refreshedSession: AuthSession?
    private var session: AuthSession?

    init(refreshedSession: AuthSession?) {
        self.refreshedSession = refreshedSession
    }

    func refreshExpiredSession(
        _ session: AuthSession,
        now: Date
    ) async throws -> AuthSession? {
        self.session = session
        return refreshedSession
    }

    func capturedSession() -> AuthSession? {
        session
    }
}

private actor CapturingAccountDataCleaner: AccountScopedDataClearing {
    private var count = 0

    func clearAccountScopedData() async throws {
        count += 1
    }

    func clearCount() -> Int {
        count
    }
}

private extension AuthSession {
    static func fixture(
        user: SessionUser = SessionUser(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            displayName: "Driver"
        ),
        expiresAt: Date = Date(timeIntervalSince1970: 2_000)
    ) -> AuthSession {
        AuthSession(
            user: user,
            accessToken: "access-token",
            refreshToken: "refresh-token",
            expiresAt: expiresAt,
            savedAt: Date(timeIntervalSince1970: 900)
        )
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
