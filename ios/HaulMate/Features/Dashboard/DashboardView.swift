//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

struct DashboardView: View {
    @Environment(\.appDependencies) private var dependencies

    let user: SessionUser

    private var router: AppRouter { dependencies.required.router }

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            DashboardTabView(user: user, state: .empty)
                .tabItem {
                    Label(DashboardStrings.todayTab.localized, systemImage: "house")
                }
                .tag(AppTab.dashboard)

            LoadsTabView()
                .tabItem {
                    Label(DashboardStrings.loadsTab.localized, systemImage: "shippingbox")
                }
                .tag(AppTab.loads)

            SettingsTabView()
                .tabItem {
                    Label(DashboardStrings.moreTab.localized, systemImage: "ellipsis.circle")
                }
                .tag(AppTab.settings)
        }
        .tint(HMColor.accent)
        .hmAppBackground()
        .toolbarBackground(HMColor.brandNavy, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .sheet(item: $router.presentedSheet) { sheet in
            switch sheet {
            case .newLoad:
                NewLoadView()
            }
        }
    }
}

#if DEBUG
#Preview {
    DashboardView(user: .preview)
        .withPreviewDependencies(user: .preview)
}
#endif
