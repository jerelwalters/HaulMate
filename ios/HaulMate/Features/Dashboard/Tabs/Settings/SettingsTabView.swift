//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

struct SettingsTabView: View {
    @Environment(\.appDependencies) private var dependencies

    private var appRootRepository: AppRootRepository {
        dependencies.required.appRootRepository
    }
    private var router: AppRouter { dependencies.required.router }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.settingsPath) {
            List {
                NavigationLink(value: SettingsRoute.businessProfile) {
                    Label("Business Profile", systemImage: "building.2")
                }

                Button(
                    "Sign Out",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    role: .destructive,
                    action: signOut
                )
            }
            .navigationTitle("Settings")
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .businessProfile:
                    Text("Business profile")
                        .navigationTitle("Business Profile")
                }
            }
        }
    }

    private func signOut() {
        router.resetForSignOut()
        Task { await appRootRepository.signOut() }
    }
}

#if DEBUG
#Preview {
    SettingsTabView()
        .withPreviewDependencies(
            user: .preview,
            selectedTab: .settings
        )
}
#endif
