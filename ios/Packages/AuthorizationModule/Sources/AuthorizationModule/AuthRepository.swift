//
//  Created by Jerel Walters on 7/1/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation
import Observation

public enum AuthenticationActionResult: Equatable, Sendable {
    case success
    case failure(AuthRepositoryError)
}

public enum AuthStatus: Equatable, Sendable {
    case loading
    case unauthenticated
    case authenticated(SessionUser)
    case failed(AuthRepositoryError)
}

public enum AuthenticatedUserActionResult: Equatable, Sendable {
    case success(SessionUser)
    case failure(AuthRepositoryError)
}

public enum BusinessProfileActionResult: Equatable, Sendable {
    case success(BusinessProfileDraft?)
    case failure(AuthRepositoryError)
}

public enum AuthRepositoryError: Error, Equatable, Sendable {
    case restoreSessionFailed
    case signInFailed
    case signUpFailed
    case businessProfileLoadFailed
    case businessProfileSaveFailed
    case passwordResetFailed
    case signOutFailed
}

public protocol AuthService: Sendable {
    func restoreSession() async throws -> SessionUser?
    func signIn(request: SignInRequest) async throws -> SessionUser
    func signUp(request: SignUpRequest) async throws -> SessionUser
    func currentBusinessProfile() async throws -> BusinessProfileDraft?
    func updateBusinessProfile(_ profile: BusinessProfileDraft) async throws -> BusinessProfileDraft
    func requestPasswordReset(email: String) async throws
    func signOut() async throws
}

@MainActor
@Observable
public final class AuthRepository {
    public private(set) var authStatus: AuthStatus = .loading

    @ObservationIgnored private let service: any AuthService
    @ObservationIgnored private var hasRestored = false

    public init(authService: any AuthService) {
        service = authService
    }

    public convenience init(
        sessionStore: any AuthSessionStoring,
        businessProfileStore: any BusinessProfileStoring,
        accountDataCleaner: any AccountScopedDataClearing,
        sessionRefresher: any AuthSessionRefreshing = NoOpAuthSessionRefresher(),
        fallbackDisplayName: String = "Driver",
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.init(
            authService: AuthSessionManager(
                sessionStore: sessionStore,
                businessProfileStore: businessProfileStore,
                sessionRefresher: sessionRefresher,
                accountDataCleaner: accountDataCleaner,
                fallbackDisplayName: fallbackDisplayName,
                now: now
            )
        )
    }

    public func restore(force: Bool = false) async {
        guard force || !hasRestored else { return }

        hasRestored = true
        authStatus = .loading

        do {
            if let user = try await service.restoreSession() {
                authStatus = .authenticated(user)
            } else {
                authStatus = .unauthenticated
            }
        } catch {
            authStatus = .failed(.restoreSessionFailed)
        }
    }

    public func completeAuthentication(with user: SessionUser) {
        authStatus = .authenticated(user)
    }

    public func signIn(request: SignInRequest) async -> AuthenticatedUserActionResult {
        do {
            let user = try await service.signIn(request: request)
            authStatus = .authenticated(user)
            return .success(user)
        } catch {
            authStatus = .unauthenticated
            return .failure(.signInFailed)
        }
    }

    public func signUp(request: SignUpRequest) async -> AuthenticatedUserActionResult {
        do {
            let user = try await service.signUp(request: request)
            authStatus = .authenticated(user)
            return .success(user)
        } catch {
            authStatus = .unauthenticated
            return .failure(.signUpFailed)
        }
    }

    public func loadBusinessProfile() async -> BusinessProfileActionResult {
        do {
            return .success(try await service.currentBusinessProfile())
        } catch {
            return .failure(.businessProfileLoadFailed)
        }
    }

    public func updateBusinessProfile(_ profile: BusinessProfileDraft) async -> BusinessProfileActionResult {
        do {
            return .success(try await service.updateBusinessProfile(profile.normalized))
        } catch {
            return .failure(.businessProfileSaveFailed)
        }
    }

    public func requestPasswordReset(email: String) async -> AuthenticationActionResult {
        do {
            try await service.requestPasswordReset(email: email)
            return .success
        } catch {
            return .failure(.passwordResetFailed)
        }
    }

    @discardableResult
    public func signOut() async -> AuthenticationActionResult {
        do {
            try await service.signOut()
            authStatus = .unauthenticated
            return .success
        } catch {
            authStatus = .unauthenticated
            return .failure(.signOutFailed)
        }
    }
}
