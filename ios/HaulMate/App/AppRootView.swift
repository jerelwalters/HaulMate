//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

struct AppRootView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.appAppearanceMode) private var appAppearanceMode

    private var authRepository: AuthRepository {
        dependencies.required.authRepository
    }
    private var router: AppRouter { dependencies.required.router }

    var body: some View {
        Group {
            switch authRepository.authStatus {
            case .loading:
                AppStatusView(state: .loading)
            case .unauthenticated:
                AuthenticationView()
            case .authenticated(let user):
                DashboardView(user: user)
            case .failed(let error):
                AppStatusView(
                    state: .failed(message: error.localizedMessage),
                    retry: retrySessionRestore
                )
            }
        }
        .task {
            await restoreSession()
        }
        .onOpenURL { url in
            router.handle(url: url)
        }
        .tint(HMColor.accent)
        .hmAppBackground()
        .preferredColorScheme(appAppearanceMode.wrappedValue.colorScheme)
    }

    private func restoreSession() async {
        await authRepository.restore()
    }

    private func retrySessionRestore() {
        Task { await authRepository.restore(force: true) }
    }
}

#if DEBUG
#Preview("Signed Out") {
    AppRootView()
        .withPreviewDependencies()
}

#Preview("Signed Out · Dark") {
    AppRootView()
        .withPreviewDependencies(appAppearanceMode: .dark)
}

#Preview("Signed In") {
    AppRootView()
        .withPreviewDependencies(user: .preview)
}

#Preview("Signed In · Dark") {
    AppRootView()
        .withPreviewDependencies(user: .preview, appAppearanceMode: .dark)
}

#Preview("Restore Failure") {
    AppRootView()
        .withPreviewDependencies(restoreShouldFail: true)
}

#Preview("Restore Failure · Dark") {
    AppRootView()
        .withPreviewDependencies(restoreShouldFail: true, appAppearanceMode: .dark)
}
#endif
