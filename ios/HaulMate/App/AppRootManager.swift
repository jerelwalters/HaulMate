//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

actor AppRootManager: AppService {
    private let sessionStore: any AuthSessionStoring
    private let sessionRefresher: any AuthSessionRefreshing
    private let accountDataCleaner: any AccountScopedDataClearing
    private let now: @Sendable () -> Date

    private var currentUser: SessionUser?
    private var businessProfile: BusinessProfileDraft?

    init(
        sessionStore: any AuthSessionStoring = HaulMateSecureSessionStore(),
        sessionRefresher: any AuthSessionRefreshing = NoOpAuthSessionRefresher(),
        accountDataCleaner: any AccountScopedDataClearing = HaulMateAccountScopedDataCleaner(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.sessionStore = sessionStore
        self.sessionRefresher = sessionRefresher
        self.accountDataCleaner = accountDataCleaner
        self.now = now
    }

    func restoreSession() async throws -> SessionUser? {
        guard let session = try await sessionStore.readSession() else {
            currentUser = nil
            businessProfile = nil
            return nil
        }

        let currentDate = now()
        guard session.isExpired(at: currentDate) else {
            currentUser = session.user
            return session.user
        }

        if let refreshedSession = try await sessionRefresher.refreshExpiredSession(
            session,
            now: currentDate
        ), !refreshedSession.isExpired(at: currentDate) {
            try await sessionStore.saveSession(refreshedSession)
            currentUser = refreshedSession.user
            return refreshedSession.user
        }

        try await sessionStore.deleteSession()
        currentUser = nil
        businessProfile = nil
        return nil
    }

    func signIn(request: SignInRequest) async throws -> SessionUser {
        let user = SessionUser(
            id: UUID(),
            displayName: displayName(fromEmail: request.email)
        )
        try await replaceStoredSession(for: user)
        return user
    }

    func signUp(request: SignUpRequest) async throws -> SessionUser {
        businessProfile = request.businessProfile

        let profileName = request.businessProfile.displayName.trimmed.isEmpty
            ? request.businessProfile.legalName
            : request.businessProfile.displayName
        let user = SessionUser(
            id: UUID(),
            displayName: profileName.trimmed
        )
        try await replaceStoredSession(for: user)
        return user
    }

    func requestPasswordReset(email: String) async throws {}

    func signOut() async throws {
        defer {
            currentUser = nil
            businessProfile = nil
        }

        try await sessionStore.deleteSession()
        try await sessionStore.deleteSessionUserID()
        try await accountDataCleaner.clearAccountScopedData()
    }

    private func replaceStoredSession(for user: SessionUser) async throws {
        try await clearAccountDataIfNeeded(for: user.id)
        try await sessionStore.saveSession(
            AuthSession.localDevelopmentSession(
                user: user,
                now: now()
            )
        )
        currentUser = user
    }

    private func clearAccountDataIfNeeded(for userID: UUID) async throws {
        let storedUserID: UUID?
        if let storedSession = try await sessionStore.readSession() {
            storedUserID = storedSession.user.id
        } else {
            storedUserID = try await sessionStore.readSessionUserID()
        }

        guard let storedUserID, storedUserID != userID else {
            return
        }

        try await accountDataCleaner.clearAccountScopedData()
    }

    private func displayName(fromEmail email: String) -> String {
        email
            .split(separator: "@")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized ?? AppStrings.pilotDriver.localized
    }
}
