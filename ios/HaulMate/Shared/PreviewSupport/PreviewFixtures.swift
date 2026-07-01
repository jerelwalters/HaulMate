//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

#if DEBUG
import Foundation
import SwiftUI

extension SessionUser {
    static let preview = SessionUser(
        id: UUID(uuidString: "7D33B9FA-14EC-462D-A59F-83FF86190326")!,
        displayName: "Jerel"
    )
}

actor PreviewAuthService: AuthService {
    private var restoredUser: SessionUser?
    private var businessProfile: BusinessProfileDraft?
    private let restoreShouldFail: Bool

    init(
        restoredUser: SessionUser?,
        restoreShouldFail: Bool = false
    ) {
        self.restoredUser = restoredUser
        self.restoreShouldFail = restoreShouldFail
    }

    func restoreSession() async throws -> SessionUser? {
        if restoreShouldFail { throw PreviewError.restore }
        return restoredUser
    }

    func signIn(request: SignInRequest) async throws -> SessionUser {
        let user = restoredUser ?? .preview
        restoredUser = user
        return user
    }

    func signUp(request: SignUpRequest) async throws -> SessionUser {
        let normalizedProfile = request.businessProfile.normalized
        businessProfile = normalizedProfile
        let profileName = normalizedProfile.displayName.isEmpty
            ? normalizedProfile.legalName
            : normalizedProfile.displayName

        let user = SessionUser(
            id: UUID(),
            displayName: profileName
        )
        restoredUser = user
        return user
    }

    func currentBusinessProfile() async throws -> BusinessProfileDraft? {
        businessProfile
    }

    func updateBusinessProfile(_ profile: BusinessProfileDraft) async throws -> BusinessProfileDraft {
        let normalizedProfile = profile.normalized
        businessProfile = normalizedProfile
        return normalizedProfile
    }

    func requestPasswordReset(email: String) async throws {}

    func signOut() async throws {
        restoredUser = nil
        businessProfile = nil
    }
}

@MainActor
extension AppDependencies {
    static func preview(
        user: SessionUser? = nil,
        restoreShouldFail: Bool = false,
        selectedTab: AppTab = .dashboard
    ) -> AppDependencies {
        let router = AppRouter(store: PreviewNavigationStateStore())
        router.selectedTab = selectedTab
        let authService = PreviewAuthService(
            restoredUser: user,
            restoreShouldFail: restoreShouldFail
        )
        let authRepository = AuthRepository(authService: authService)

        return AppDependencies(
            authRepository: authRepository,
            router: router
        )
    }
}

@MainActor
extension View {
    func withPreviewDependencies(
        user: SessionUser? = nil,
        restoreShouldFail: Bool = false,
        selectedTab: AppTab = .dashboard,
        appAppearanceMode: AppAppearanceMode = .system
    ) -> some View {
        environment(
            \.appDependencies,
            AppDependencies.preview(
                user: user,
                restoreShouldFail: restoreShouldFail,
                selectedTab: selectedTab
            )
        )
        .environment(\.appAppearanceMode, .constant(appAppearanceMode))
    }
}

private enum PreviewError: Error {
    case restore
}

@MainActor
private final class PreviewNavigationStateStore: NavigationStatePersisting {
    func load() -> Data? { nil }
    func save(_ data: Data) {}
}
#endif
