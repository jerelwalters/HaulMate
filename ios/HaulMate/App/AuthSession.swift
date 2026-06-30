//
//  Created by Jerel Walters on 6/30/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

struct AuthSession: Codable, Equatable, Sendable {
    private static let localDevelopmentLifetime: TimeInterval = 24 * 60 * 60

    let user: SessionUser
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let savedAt: Date

    init(
        user: SessionUser,
        accessToken: String,
        refreshToken: String,
        expiresAt: Date,
        savedAt: Date
    ) {
        self.user = user
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.savedAt = savedAt
    }

    static func localDevelopmentSession(
        user: SessionUser,
        now: Date
    ) -> AuthSession {
        // P0-MOB-02 follow-up replaces these local-development tokens with Supabase Auth session material.
        AuthSession(
            user: user,
            accessToken: UUID().uuidString,
            refreshToken: UUID().uuidString,
            expiresAt: now.addingTimeInterval(localDevelopmentLifetime),
            savedAt: now
        )
    }

    func isExpired(at date: Date) -> Bool {
        expiresAt <= date
    }
}

protocol AuthSessionStoring: Sendable {
    func readSession() async throws -> AuthSession?
    func readSessionUserID() async throws -> UUID?
    func saveSession(_ session: AuthSession) async throws
    func deleteSession() async throws
    func deleteSessionUserID() async throws
}

protocol AuthSessionRefreshing: Sendable {
    func refreshExpiredSession(
        _ session: AuthSession,
        now: Date
    ) async throws -> AuthSession?
}

struct NoOpAuthSessionRefresher: AuthSessionRefreshing {
    func refreshExpiredSession(
        _ session: AuthSession,
        now: Date
    ) async throws -> AuthSession? {
        nil
    }
}

protocol AccountScopedDataClearing: Sendable {
    func clearAccountScopedData() async throws
}
