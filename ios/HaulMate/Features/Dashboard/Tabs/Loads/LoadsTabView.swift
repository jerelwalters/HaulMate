//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

struct LoadsTabView: View {
    @Environment(\.appDependencies) private var dependencies

    private var router: AppRouter { dependencies.required.router }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.loadsPath) {
            AppStatusView(
                state: .offline(
                    message: "Saved loads will remain available here while you're offline."
                )
            )
            .navigationTitle("Loads")
            .navigationDestination(for: LoadsRoute.self) { route in
                switch route {
                case .load(let id):
                    LoadDetailView(loadID: id)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: showNewLoad) {
                        Label("New Load", systemImage: "plus")
                    }
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
    LoadsTabView()
        .withPreviewDependencies(
            user: .preview,
            selectedTab: .loads
        )
}
#endif
