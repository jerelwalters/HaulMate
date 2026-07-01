//
//  Created by Jerel Walters on 7/1/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation

public struct AuthSession: Codable, Equatable, Sendable {
    private static let localDevelopmentLifetime: TimeInterval = 24 * 60 * 60

    public let user: SessionUser
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let savedAt: Date

    public init(
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

    public static func localDevelopmentSession(
        user: SessionUser,
        now: Date
    ) -> AuthSession {
        AuthSession(
            user: user,
            accessToken: UUID().uuidString,
            refreshToken: UUID().uuidString,
            expiresAt: now.addingTimeInterval(localDevelopmentLifetime),
            savedAt: now
        )
    }

    public func isExpired(at date: Date) -> Bool {
        expiresAt <= date
    }
}

public protocol AuthSessionStoring: Sendable {
    func readSession() async throws -> AuthSession?
    func readSessionUserID() async throws -> UUID?
    func saveSession(_ session: AuthSession) async throws
    func deleteSession() async throws
    func deleteSessionUserID() async throws
}

public protocol BusinessProfileStoring: Sendable {
    func readBusinessProfile() async throws -> BusinessProfileDraft?
    func saveBusinessProfile(_ profile: BusinessProfileDraft) async throws
}

public protocol AuthSessionRefreshing: Sendable {
    func refreshExpiredSession(
        _ session: AuthSession,
        now: Date
    ) async throws -> AuthSession?
}

public struct NoOpAuthSessionRefresher: AuthSessionRefreshing {
    public init() {}

    public func refreshExpiredSession(
        _ session: AuthSession,
        now: Date
    ) async throws -> AuthSession? {
        nil
    }
}

public protocol AccountScopedDataClearing: Sendable {
    func clearAccountScopedData() async throws
}
