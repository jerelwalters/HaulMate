//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

struct DashboardTabView: View {
    @Environment(\.appDependencies) private var dependencies

    let user: SessionUser

    private var router: AppRouter { dependencies.required.router }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.dashboardPath) {
            AppStatusView(
                state: .empty(
                    title: "No active load",
                    message: "Create a load when you're ready to evaluate your next run."
                )
            )
            .navigationTitle("Hi, \(user.displayName)")
            .navigationDestination(for: DashboardRoute.self) { route in
                switch route {
                case .activeLoad(let id):
                    LoadDetailView(loadID: id)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: showNewLoad) {
                        Label("New Load", systemImage: "plus")
                    }
                    .accessibilityIdentifier("dashboard.new-load")
                }
            }
        }
    }

    private func showNewLoad() {
        router.presentedSheet = .newLoad
    }
}

#if DEBUG
#Preview {
    DashboardTabView(user: .preview)
        .withPreviewDependencies(user: .preview)
}
#endif
