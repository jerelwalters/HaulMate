//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

@main
struct HaulMateApp: App {
    @AppStorage("appAppearanceMode") private var appAppearanceMode = AppAppearanceMode.system

    @State private var authRepository: AuthRepository
    @State private var router: AppRouter

    init() {
        _authRepository = State(initialValue: AuthRepository())
        _router = State(initialValue: AppRouter())
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(
                    \.appDependencies,
                    AppDependencies(
                        authRepository: authRepository,
                        router: router
                    )
                )
                .environment(\.appAppearanceMode, $appAppearanceMode)
        }
    }
}
