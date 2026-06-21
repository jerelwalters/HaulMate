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

actor PreviewAppService: AppService {
    private var restoredUser: SessionUser?
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
        let user = SessionUser(
            id: UUID(),
            displayName: request.businessProfile.displayName.trimmed.isEmpty
                ? request.businessProfile.legalName
                : request.businessProfile.displayName
        )
        restoredUser = user
        return user
    }

    func requestPasswordReset(email: String) async throws {}

    func signOut() async {
        restoredUser = nil
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

        return AppDependencies(
            appRootRepository: AppRootRepository(
                appService: PreviewAppService(
                    restoredUser: user,
                    restoreShouldFail: restoreShouldFail
                )
            ),
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
