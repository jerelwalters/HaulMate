//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

// MOB-02: Supabase session/user/profile mapping belongs behind this manager;
// AuthRepository stays vendor-neutral for app and feature callers.
actor AuthSessionManager: AuthService {
    private let sessionStore: any AuthSessionStoring
    private let businessProfileStore: any BusinessProfileStoring
    private let sessionRefresher: any AuthSessionRefreshing
    private let accountDataCleaner: any AccountScopedDataClearing
    private let fallbackDisplayName: String
    private let now: @Sendable () -> Date

    private var currentUser: SessionUser?
    private var businessProfile: BusinessProfileDraft?

    init(
        sessionStore: any AuthSessionStoring,
        businessProfileStore: any BusinessProfileStoring,
        sessionRefresher: any AuthSessionRefreshing = NoOpAuthSessionRefresher(),
        accountDataCleaner: any AccountScopedDataClearing,
        fallbackDisplayName: String = "Driver",
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.sessionStore = sessionStore
        self.businessProfileStore = businessProfileStore
        self.sessionRefresher = sessionRefresher
        self.accountDataCleaner = accountDataCleaner
        self.fallbackDisplayName = fallbackDisplayName
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
            businessProfile = try await businessProfileStore.readBusinessProfile()
            return session.user
        }

        if let refreshedSession = try await sessionRefresher.refreshExpiredSession(
            session,
            now: currentDate
        ), !refreshedSession.isExpired(at: currentDate) {
            try await sessionStore.saveSession(refreshedSession)
            currentUser = refreshedSession.user
            businessProfile = try await businessProfileStore.readBusinessProfile()
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
        businessProfile = try await businessProfileStore.readBusinessProfile()
        return user
    }

    func signUp(request: SignUpRequest) async throws -> SessionUser {
        let normalizedProfile = request.businessProfile.normalized

        let profileName = normalizedProfile.displayName.isEmpty
            ? normalizedProfile.legalName
            : normalizedProfile.displayName
        let user = SessionUser(
            id: UUID(),
            displayName: profileName
        )
        try await replaceStoredSession(for: user)
        try await businessProfileStore.saveBusinessProfile(normalizedProfile)
        businessProfile = normalizedProfile
        return user
    }

    func currentBusinessProfile() async throws -> BusinessProfileDraft? {
        guard currentUser != nil else { return nil }

        if let businessProfile {
            return businessProfile
        }

        let storedProfile = try await businessProfileStore.readBusinessProfile()
        businessProfile = storedProfile
        return storedProfile
    }

    func updateBusinessProfile(_ profile: BusinessProfileDraft) async throws -> BusinessProfileDraft {
        guard currentUser != nil else { throw AuthSessionManagerError.unauthenticated }

        let normalizedProfile = profile.normalized
        try await businessProfileStore.saveBusinessProfile(normalizedProfile)
        businessProfile = normalizedProfile
        return normalizedProfile
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
            .capitalized ?? fallbackDisplayName
    }
}

private enum AuthSessionManagerError: Error {
    case unauthenticated
}
