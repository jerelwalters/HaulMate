//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation
import Observation

struct SessionUser: Equatable, Sendable {
    let id: UUID
    let displayName: String
}

enum AppRootPhase: Equatable {
    case loading
    case unauthenticated
    case authenticated(SessionUser)
    case failed(message: String)
}

enum AuthenticationActionResult: Equatable {
    case success
    case failure(message: String)
}

@MainActor
@Observable
final class AppRootRepository {
    private(set) var phase: AppRootPhase = .loading

    @ObservationIgnored private let service: any AppService
    @ObservationIgnored private var hasRestored = false

    init(appService: any AppService) {
        service = appService
    }

    convenience init() {
        self.init(appService: AppRootManager())
    }

    func restore(force: Bool = false) async {
        guard force || !hasRestored else { return }

        hasRestored = true
        phase = .loading

        do {
            if let user = try await service.restoreSession() {
                phase = .authenticated(user)
            } else {
                phase = .unauthenticated
            }
        } catch {
            phase = .failed(message: AppRootStrings.restoreSessionFailure.localized)
        }
    }

    func signIn(request: SignInRequest) async -> AuthenticationActionResult {
        do {
            phase = .authenticated(try await service.signIn(request: request))
            return .success
        } catch {
            phase = .unauthenticated
            return .failure(message: AppRootStrings.signInFailure.localized)
        }
    }

    func signUp(request: SignUpRequest) async -> AuthenticationActionResult {
        do {
            phase = .authenticated(try await service.signUp(request: request))
            return .success
        } catch {
            phase = .unauthenticated
            return .failure(message: AppRootStrings.signUpFailure.localized)
        }
    }

    func requestPasswordReset(email: String) async -> AuthenticationActionResult {
        do {
            try await service.requestPasswordReset(email: email)
            return .success
        } catch {
            return .failure(message: AppRootStrings.passwordResetFailure.localized)
        }
    }

    func signOut() async {
        await service.signOut()
        phase = .unauthenticated
    }
}
