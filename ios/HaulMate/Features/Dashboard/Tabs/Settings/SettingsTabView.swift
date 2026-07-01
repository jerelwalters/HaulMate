//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

struct SettingsTabView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.appAppearanceMode) private var appAppearanceMode

    private var authRepository: AuthRepository {
        dependencies.required.authRepository
    }
    private var router: AppRouter { dependencies.required.router }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.settingsPath) {
            List {
                VStack(alignment: .leading, spacing: HMSpacing.sm) {
                    Label(SettingsStrings.appearanceLabel.localized, systemImage: "circle.lefthalf.filled")

                    Picker(SettingsStrings.appearanceLabel.localized, selection: appAppearanceMode) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            Text(mode.title)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(HMColor.surface)

                NavigationLink(value: SettingsRoute.businessProfile) {
                    Label(SettingsStrings.businessProfileLabel.localized, systemImage: "building.2")
                }
                .listRowBackground(HMColor.surface)

                NavigationLink(value: SettingsRoute.truckCostProfile) {
                    Label(SettingsStrings.truckCostProfileLabel.localized, systemImage: "truck.box")
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
                    BusinessProfileView()
                case .truckCostProfile:
                    TruckCostProfileView()
                }
            }
        }
    }

    private func signOut() {
        router.resetForSignOut()
        Task { await authRepository.signOut() }
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

#Preview("Dark") {
    SettingsTabView()
        .withPreviewDependencies(
            user: .preview,
            selectedTab: .settings,
            appAppearanceMode: .dark
        )
        .preferredColorScheme(.dark)
}
#endif
