//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

struct AppRootView: View {
    @Environment(\.appDependencies) private var dependencies

    private var appRootRepository: AppRootRepository {
        dependencies.required.appRootRepository
    }
    private var router: AppRouter { dependencies.required.router }

    var body: some View {
        Group {
            switch appRootRepository.phase {
            case .loading:
                AppStatusView(state: .loading)
            case .unauthenticated:
                AuthenticationView()
            case .authenticated(let user):
                DashboardView(user: user)
            case .failed(let message):
                AppStatusView(
                    state: .failed(message: message),
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
    }

    private func restoreSession() async {
        await appRootRepository.restore()
    }

    private func retrySessionRestore() {
        Task { await appRootRepository.restore(force: true) }
    }
}

#if DEBUG
#Preview("Signed Out") {
    AppRootView()
        .withPreviewDependencies()
}

#Preview("Signed In") {
    AppRootView()
        .withPreviewDependencies(user: .preview)
}

#Preview("Restore Failure") {
    AppRootView()
        .withPreviewDependencies(restoreShouldFail: true)
}
#endif
