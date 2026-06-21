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
            DashboardTabView(user: user)
                .tabItem {
                    Label("Dashboard", systemImage: "rectangle.grid.2x2")
                }
                .tag(AppTab.dashboard)

            LoadsTabView()
                .tabItem {
                    Label("Loads", systemImage: "shippingbox")
                }
                .tag(AppTab.loads)

            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
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
