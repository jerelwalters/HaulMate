//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

@MainActor
struct AppDependencies {
    let appRootRepository: AppRootRepository
    let router: AppRouter
}

extension EnvironmentValues {
    @Entry var appDependencies: AppDependencies?
}

extension Optional where Wrapped == AppDependencies {
    @MainActor
    var required: AppDependencies {
        guard let self else {
            preconditionFailure("AppDependencies must be injected at the app root.")
        }
        return self
    }
}
