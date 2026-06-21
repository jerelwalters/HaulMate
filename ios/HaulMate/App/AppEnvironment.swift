//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system:
            return AppAppearanceStrings.systemTitle.localized
        case .light:
            return AppAppearanceStrings.lightTitle.localized
        case .dark:
            return AppAppearanceStrings.darkTitle.localized
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

@MainActor
struct AppDependencies {
    let appRootRepository: AppRootRepository
    let router: AppRouter
}

extension EnvironmentValues {
    @Entry var appDependencies: AppDependencies?
    @Entry var appAppearanceMode: Binding<AppAppearanceMode> = .constant(.system)
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
