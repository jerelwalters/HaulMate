//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

@main
struct HaulMateApp: App {
    @AppStorage("appAppearanceMode") private var appAppearanceMode = AppAppearanceMode.system

    @State private var appRootRepository: AppRootRepository
    @State private var router: AppRouter

    init() {
        _appRootRepository = State(initialValue: AppRootRepository())
        _router = State(initialValue: AppRouter())
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(
                    \.appDependencies,
                    AppDependencies(
                        appRootRepository: appRootRepository,
                        router: router
                    )
                )
                .environment(\.appAppearanceMode, $appAppearanceMode)
        }
    }
}
