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
            phase = .failed(message: "We couldn't restore your session.")
        }
    }

    func signIn() async {
        phase = .loading

        do {
            phase = .authenticated(try await service.signIn())
        } catch {
            phase = .failed(message: "We couldn't sign you in.")
        }
    }

    func signOut() async {
        await service.signOut()
        phase = .unauthenticated
    }
}
