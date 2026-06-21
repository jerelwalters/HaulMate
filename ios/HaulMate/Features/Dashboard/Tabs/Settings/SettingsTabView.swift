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
                    Label(SettingsStrings.businessProfileLabel.localized, systemImage: "building.2")
                }
                .listRowBackground(HMColor.surface)

                Button(
                    SettingsStrings.signOutButton.localized,
                    systemImage: "rectangle.portrait.and.arrow.right",
                    role: .destructive,
                    action: signOut
                )
                .listRowBackground(HMColor.surface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(HMColor.canvas)
            .tint(HMColor.accent)
            .navigationTitle(SettingsStrings.navigationTitle.localized)
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .businessProfile:
                    Text(SettingsStrings.businessProfilePlaceholder.localized)
                        .font(HMFont.body)
                        .foregroundStyle(HMColor.textPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .hmAppBackground()
                        .navigationTitle(SettingsStrings.businessProfileLabel.localized)
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
